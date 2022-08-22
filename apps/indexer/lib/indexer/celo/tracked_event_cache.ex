defmodule Indexer.Celo.TrackedEventCache do
  @moduledoc "Maintains ets tables representing events that are to be tracked + functions to filter tracked events"

  use GenServer

  require Logger
  import Ecto.Query

  alias ABI.FunctionSelector
  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Repo

  require Explorer.Celo.Telemetry, as: Telemetry

  @cache_refresh_interval :timer.minutes(5)

  def start_link([init_arg, gen_server_opts]) do
    start_link(init_arg, gen_server_opts)
  end

  def start_link(init_arg, gen_server_opts) do
    gen_server_opts = Keyword.merge(gen_server_opts, name: __MODULE__)

    GenServer.start_link(__MODULE__, init_arg, gen_server_opts)
  end

  @impl true
  def init(_) do
    state = %{
      table_ref: nil
    }

    {:ok, state, {:continue, :populate_cache}}
  end

  @impl true
  def handle_continue(:populate_cache, state) do
    # create ets table
    cache_table = :ets.new(__MODULE__, [:set, :protected, :named_table, read_concurrency: true])

    cache_table |> build_cache()

    Process.send_after(__MODULE__, :refresh_cache, @cache_refresh_interval)

    {:noreply, %{state | table_ref: cache_table}}
  end

  def rebuild_cache do
    GenServer.call(__MODULE__, :rebuild_cache)
  end

  @impl true
  def handle_call(:rebuild_cache, _from, %{table_ref: table} = state) do
    build_cache(table)
    {:reply, nil, state}
  end

  def handle_info(:refresh_cache, %{table_ref: table} = state) do
    build_cache(table)
    Process.send_after(__MODULE__, :refresh_cache, @cache_refresh_interval)
    {:noreply, state}
  end

  defp build_cache(table_ref) do
    query =
      from(
        et in ContractEventTracking,
        where: et.enabled == true,
        preload: [:smart_contract]
      )

    cache_values =
      query
      |> Repo.all()
      |> Enum.map(fn cet = %ContractEventTracking{} -> {cet |> event_id(), cet} end)

    Logger.info("TrackedEventCache - building cache with #{length(cache_values)} entries")

    table_ref |> :ets.delete_all_objects()

    cache_values
    |> Enum.each(fn {cache_id, cet} ->
      function_selector = FunctionSelector.parse_specification_item(cet.abi)

      table_ref
      |> :ets.insert({cache_id, function_selector, cet})
    end)
  end

  def filter_tracked(events) when is_list(events) do
    events
    |> Enum.filter(&tracked_event?/1)
  end

  @doc "Accepts a list of logs / events for processing and batches them into tuples of {[tracked_logs], event_function_selector} for batch processing"
  def batch_events(events) when is_list(events) do
    events
    |> filter_tracked()
    |> Enum.group_by(&event_id/1)
    |> Map.values()
    |> Enum.map(fn logs ->
      [{_id, function_selector, contract_event_tracking}] =
        logs
        |> List.first()
        |> event_id()
        |> then(&:ets.lookup(__MODULE__, &1))

      {logs, function_selector, contract_event_tracking.id}
    end)
  end

  defp tracked_event?(event) do
    :ets.lookup(__MODULE__, event_id(event)) != []
  end

  # calculating event id as a tuple of {event_topic, contract_address}
  @doc false
  def event_id(%{topic: topic, smart_contract: sc}) do
    {topic, sc.address_hash |> to_string()}
  end

  @doc false
  def event_id(%{first_topic: topic, address_hash: address_hash}) do
    {topic, address_hash |> to_string()}
  end
end
