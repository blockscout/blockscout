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
  `CACHE_TOP_ADDRESSES_UPDATE_INTERVAL`). A refill replaces the whole content
  of the cache, which renews the TTL of the entries, so as long as the interval
  is shorter than the TTL (`CACHE_TOP_ADDRESSES_TTL`) the cache never expires on
  an API node, and an entry whose balance changed does not linger next to its
  replacement.

  It also serializes the on-demand refills that
  `Explorer.Chain.Address.list_top_addresses/1` falls back to when the cache
  cannot serve a request: right after boot, after the indexer dropped the
  entries, or once refreshes have failed for longer than the TTL. At most one
  refill runs at a time, in a task, always for the whole cache; requests
  arriving while it runs wait for it and all receive its result — their page of
  the addresses, or the same failure — so the query runs once per miss instead
  of once per request, whether it succeeds or not. The interval is measured
  from the last refill, whatever started it.

  When the process is not running, `fetch_top_addresses/1` runs the query in
  the calling process, exactly as the request path did before.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Accounts

  @typep result :: {:ok, [Address.t()]} | {:error, {atom(), term(), Exception.stacktrace()}}

  # `refill` is the monitor reference of the running task, or `nil`; `waiters`
  # are the callers to answer when it completes, with the page size each asked
  # for; `timer` is the reference of the next scheduled periodic refill.
  @typep state :: %{
           refill: reference() | nil,
           waiters: [{GenServer.from(), non_neg_integer()}],
           timer: reference() | nil
         }

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    send(self(), :refresh)

    {:ok, %{refill: nil, waiters: [], timer: nil}}
  end

  @impl true
  def handle_info(:refresh, state) do
    # A refill already running fills the cache just as well.
    {:noreply, maybe_start_refill(state)}
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
  def handle_call({:fetch, page_size}, from, state) do
    # A refill that finished while this request was queued already serves it.
    case Accounts.atomic_take_enough(page_size) do
      nil -> {:noreply, state |> add_waiter(from, page_size) |> maybe_start_refill()}
      addresses -> {:reply, {:ok, addresses}, state}
    end
  end

  @doc """
  Returns the `page_size` top addresses, refilling the cache from the database
  when it cannot serve them.

  Concurrent calls share one database query and its outcome: a failed query
  raises in every caller, as a direct query would. When the process is not
  running, the caller refills the cache itself. When the refill does not
  complete within twice the repo's query timeout the call exits, so that the
  requests waiting on a slow database do not each start a query of their own.
  """
  @spec fetch_top_addresses(non_neg_integer()) :: [Address.t()]
  def fetch_top_addresses(page_size) do
    case GenServer.call(__MODULE__, {:fetch, page_size}, call_timeout()) do
      {:ok, addresses} -> addresses
      {:error, {kind, reason, stacktrace}} -> :erlang.raise(kind, reason, stacktrace)
    end
  catch
    # The process is not running: disabled, or on its way down.
    :exit, {:noproc, _} -> Address.fetch_and_cache_top_addresses() |> Enum.take(page_size)
  end

  @spec add_waiter(state(), GenServer.from(), non_neg_integer()) :: state()
  defp add_waiter(state, from, page_size), do: %{state | waiters: [{from, page_size} | state.waiters]}

  @spec maybe_start_refill(state()) :: state()
  defp maybe_start_refill(%{refill: nil} = state) do
    %Task{ref: ref} = Task.Supervisor.async_nolink(Explorer.TaskSupervisor, &fetch/0)

    %{state | refill: ref}
  end

  defp maybe_start_refill(state), do: state

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

    Enum.each(waiters, fn {from, page_size} ->
      GenServer.reply(from, with({:ok, addresses} <- result, do: {:ok, Enum.take(addresses, page_size)}))
    end)

    state
    |> schedule_refresh()
    |> Map.merge(%{refill: nil, waiters: []})
  end

  # The next periodic refill is due one interval after the one that just
  # completed, so a refill started by a request does not get followed by a
  # periodic one right away.
  @spec schedule_refresh(state()) :: state()
  defp schedule_refresh(%{timer: timer} = state) do
    if timer do
      Process.cancel_timer(timer)

      # The timer may have fired while the refill was running.
      receive do
        :refresh -> :ok
      after
        0 -> :ok
      end
    end

    %{state | timer: Process.send_after(self(), :refresh, update_interval())}
  end

  @spec fetch() :: result()
  defp fetch do
    {:ok, Address.fetch_and_cache_top_addresses()}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  # A refill runs the top-addresses query and then the cache's preload, each
  # bounded by the repo's query timeout, and a request may join it at any point.
  defp call_timeout do
    2 * (Application.get_env(:explorer, Explorer.Repo)[:timeout] || :timer.seconds(15))
  end

  defp update_interval do
    Application.get_env(:explorer, __MODULE__)[:update_interval]
  end
end
