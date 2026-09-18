# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Accounts.Refresher do
  @moduledoc """
  Keeps `Explorer.Chain.Cache.Accounts`, the top-addresses cache behind
  `/api/v2/addresses`, filled without a request having to pay for it.

  In `:all` mode the indexer empties the cache whenever a cached address changes
  its balance; in `:api` mode nothing tells the node about balance changes, so
  the entries expire on a TTL instead. Either way the cache used to be refilled
  by the next request, which ran the top-addresses query itself — hundreds of
  milliseconds on a large `addresses` table — and so did every other request
  arriving while that query was running.

  This process refills the cache on an interval (`:update_interval`,
  `CACHE_TOP_ADDRESSES_UPDATE_INTERVAL`), which also renews the TTL of the
  entries, so as long as the interval is shorter than the TTL
  (`CACHE_TOP_ADDRESSES_TTL`) the cache never expires on an API node.

  It also serializes the on-demand refills that
  `Explorer.Chain.Address.list_top_addresses/1` falls back to when the cache
  cannot serve a request: right after boot, after the indexer dropped the
  entries, or once refreshes have failed for longer than the TTL. At most one
  refill runs at a time, in a task; requests arriving while it runs wait for it
  and all receive its result — the addresses, or the same failure — so the query
  runs once per miss instead of once per request, whether it succeeds or not.

  When the process is not running, `fetch_top_addresses/1` runs the query in
  the calling process, exactly as the request path did before.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.PagingOptions

  # Bound on how long a request waits for a refill in progress. The refill itself
  # is bounded by the repo's query timeout; this only has to outlast it.
  @call_timeout :timer.minutes(1)

  @typep result :: {:ok, [Address.t()]} | {:error, {atom(), term(), Exception.stacktrace()}}

  # `refill` is the monitor reference of the running task, or `nil`; `waiters`
  # are the callers to answer when it completes, each tagged with the reply
  # shape they expect.
  @typep state :: %{refill: reference() | nil, waiters: [{GenServer.from(), :fetch | :refresh}]}

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    send(self(), :refresh)

    {:ok, %{refill: nil, waiters: []}}
  end

  @impl true
  def handle_info(:refresh, state) do
    Process.send_after(self(), :refresh, update_interval())

    # A refill already running fills the cache just as well.
    {:noreply, maybe_start_refill(state, default_options(), nil)}
  end

  # The task finished: hand its result to everyone who waited for it.
  def handle_info({ref, result}, %{refill: ref} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, complete_refill(state, result)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{refill: ref} = state) do
    {:noreply, complete_refill(state, {:error, {:exit, reason, []}})}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_call(:refresh, from, state) do
    {:noreply, state |> add_waiter(from, :refresh) |> maybe_start_refill(default_options(), nil)}
  end

  def handle_call({:fetch, options}, {caller, _tag} = from, state) do
    page_size = Keyword.fetch!(options, :paging_options).page_size

    # A refill that finished while this request was queued already serves it.
    case Accounts.atomic_take_enough(page_size) do
      nil -> {:noreply, state |> add_waiter(from, :fetch) |> maybe_start_refill(options, caller)}
      addresses -> {:reply, {:ok, addresses}, state}
    end
  end

  @doc """
  Returns the top addresses for `options`, refilling the cache from the database
  when it cannot serve them.

  Concurrent calls share one database query and its outcome. `options` must
  carry `:paging_options`; a failed query raises in the caller, as a direct
  query would.
  """
  @spec fetch_top_addresses(keyword()) :: [Address.t()]
  def fetch_top_addresses(options) do
    case GenServer.call(__MODULE__, {:fetch, options}, @call_timeout) do
      {:ok, addresses} -> addresses
      {:error, {kind, reason, stacktrace}} -> :erlang.raise(kind, reason, stacktrace)
    end
  catch
    # The process is not running — disabled, or on its way down — or did not
    # answer within the timeout, so the request refills the cache itself.
    :exit, _ -> Address.fetch_and_cache_top_addresses(options)
  end

  @doc """
  Refills the cache now, without waiting for the next interval, and waits for
  the refill to complete.

  Returns `:ok`, or `:error` when the query failed (the cache keeps its previous
  entries in that case).
  """
  @spec refresh() :: :ok | :error
  def refresh do
    GenServer.call(__MODULE__, :refresh, @call_timeout)
  end

  @spec add_waiter(state(), GenServer.from(), :fetch | :refresh) :: state()
  defp add_waiter(state, from, kind), do: %{state | waiters: [{from, kind} | state.waiters]}

  @spec maybe_start_refill(state(), keyword(), pid() | nil) :: state()
  defp maybe_start_refill(%{refill: nil} = state, options, caller) do
    %Task{ref: ref} =
      Task.Supervisor.async_nolink(Explorer.TaskSupervisor, fn ->
        # Listing the requester in `$callers` lets tooling that attributes work
        # to the requesting process — Ecto's sandbox, telemetry handlers scoped
        # to a request — see through the hop into this task.
        if caller, do: Process.put(:"$callers", [caller | Process.get(:"$callers", [])])

        fetch(options)
      end)

    %{state | refill: ref}
  end

  defp maybe_start_refill(state, _options, _caller), do: state

  @spec complete_refill(state(), result()) :: state()
  defp complete_refill(%{waiters: waiters} = state, result) do
    case result do
      {:ok, _addresses} ->
        :ok

      {:error, {kind, reason, _stacktrace}} ->
        # Reads keep the previous entries until the next interval. Letting this
        # crash would restart the process in a loop for as long as the database
        # is unreachable.
        Logger.error("Failed to refresh the top addresses cache: #{Exception.format_banner(kind, reason)}")
    end

    Enum.each(waiters, fn
      {from, :fetch} -> GenServer.reply(from, result)
      {from, :refresh} -> GenServer.reply(from, if(match?({:ok, _}, result), do: :ok, else: :error))
    end)

    %{state | refill: nil, waiters: []}
  end

  @spec fetch(keyword()) :: result()
  defp fetch(options) do
    {:ok, Address.fetch_and_cache_top_addresses(options)}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  defp default_options do
    [paging_options: %PagingOptions{page_size: Accounts.max_size()}, api?: true]
  end

  defp update_interval do
    Application.get_env(:explorer, __MODULE__)[:update_interval]
  end
end
