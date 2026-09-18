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
  entries, or once refreshes have failed for longer than the TTL. Requests
  arriving while a refill is running wait for it and are served from its result,
  so the query runs once per miss instead of once per request.

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

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    send(self(), :refresh)

    {:ok, nil}
  end

  @impl true
  def handle_info(:refresh, state) do
    refill()
    Process.send_after(self(), :refresh, update_interval())

    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    {:reply, refill(), state}
  end

  def handle_call({:fetch, options}, {caller, _tag}, state) do
    page_size = Keyword.fetch!(options, :paging_options).page_size

    # A refill that finished while this request was queued already serves it.
    result =
      case Accounts.atomic_take_enough(page_size) do
        nil -> fetch_on_behalf_of(caller, options)
        addresses -> {:ok, addresses}
      end

    {:reply, result, state}
  end

  @doc """
  Returns the top addresses for `options`, refilling the cache from the database
  when it cannot serve them.

  Concurrent calls share one database query. `options` must carry
  `:paging_options`; a failed query raises in the caller, as a direct query
  would.
  """
  @spec fetch_top_addresses(keyword()) :: [Address.t()]
  def fetch_top_addresses(options) do
    case GenServer.call(__MODULE__, {:fetch, options}, @call_timeout) do
      {:ok, addresses} -> addresses
      {:error, error, stacktrace} -> reraise(error, stacktrace)
    end
  catch
    # The process is not running — disabled, or on its way down — or did not
    # answer within the timeout, so the request refills the cache itself.
    :exit, _ -> Address.fetch_and_cache_top_addresses(options)
  end

  @doc """
  Refills the cache now, without waiting for the next interval.

  Returns `:ok`, or `:error` when the query failed (the cache keeps its previous
  entries in that case).
  """
  @spec refresh() :: :ok | :error
  def refresh do
    GenServer.call(__MODULE__, :refresh, @call_timeout)
  end

  defp refill do
    options = [paging_options: %PagingOptions{page_size: Accounts.max_size()}, api?: true]

    case fetch(options) do
      {:ok, _addresses} ->
        :ok

      {:error, error, _stacktrace} ->
        # Reads keep the previous entries until the next interval. Letting this
        # crash would restart the process in a loop for as long as the database
        # is unreachable.
        Logger.error("Failed to refresh the top addresses cache: #{Exception.message(error)}")

        :error
    end
  end

  # Runs the query on behalf of `caller`: listing it in `$callers` lets tooling
  # that attributes work to the requesting process — Ecto's sandbox, telemetry
  # handlers scoped to a request — see through the hop into this process.
  defp fetch_on_behalf_of(caller, options) do
    Process.put(:"$callers", [caller])

    fetch(options)
  after
    Process.delete(:"$callers")
  end

  defp fetch(options) do
    {:ok, Address.fetch_and_cache_top_addresses(options)}
  rescue
    error -> {:error, error, __STACKTRACE__}
  end

  defp update_interval do
    Application.get_env(:explorer, __MODULE__)[:update_interval]
  end
end
