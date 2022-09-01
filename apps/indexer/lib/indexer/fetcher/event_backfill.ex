defmodule Indexer.Fetcher.EventBackfill do
  @moduledoc "Fetch historical and missing events for the event processor"

  use Indexer.Fetcher
  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Celo.Events.Transformer
  alias Explorer.Celo.Telemetry
  alias Explorer.Chain
  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Log
  alias Explorer.Repo
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.{EventProcessor,Util}

  require Telemetry

  use BufferedTask
  import Ecto.Query

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 1,
    max_concurrency: 1,
    dedup_entries: true,
    poll: true,
    poll_interval: :timer.minutes(3),
    task_supervisor: Indexer.Fetcher.EventBackfill.TaskSupervisor,
    metadata: [fetcher: :event_backfill],
    state: %{
      page_size: 1000,
      throttle_time: 100
    }
  ]

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_events_to_backfill(initial, fn {address, event_topic, tracking_id}, acc ->
        #start backfill from {block_number, log_index} = {0,0}
        {address, event_topic, {0,0}, tracking_id}
        |> reducer.(acc)
      end)

    final
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options
    |> Keyword.merge(@defaults)
    |> Util.default_child_spec(gen_server_options, __MODULE__)
  end

  #deduplicates entries based on the contract address and topic
  @impl BufferedTask
  def dedup_entries( %BufferedTask{dedup_entries: true, bound_queue: bound_queue} = task, entries) do
    contract_address_and_topic = fn {_address, _topic, _progress, tracking_id} -> tracking_id end

    running_entries =
      task
      |> currently_processed_items()
      |> then(&(&1 ++ bound_queue))
      |> Enum.map(contract_address_and_topic)
      |> MapSet.new()

    entries
    |> Enum.uniq_by(contract_address_and_topic)
    |> Enum.filter(fn i ->
      MapSet.member?(running_entries, contract_address_and_topic.(i)) == false
    end)
  end

  @impl BufferedTask
  def run([{address, topic, from, tracking_id}] , %{page_size: page_size, throttle_time: throttle}) do
    events = get_page_of_events(address, topic, from, page_size)
    EventProcessor.enqueue_logs(events)

    Process.sleep(throttle)

    if length(events) < page_size do
      Logger.info("Completed backfill of event #{topic} on contract #{address |> to_string()}")
      mark_backfill_complete(tracking_id)
      :ok
    else
      %Log{block_number: max_bn, index: max_i} = events |> Enum.max_by(fn %Log{block_number: bn, index: i} -> {bn, i} end)

      Logger.debug("Backfilled page size #{page_size} of event #{topic} on contract #{address |> to_string()} - block_number:#{max_bn} index:#{max_i}")
      {:retry, [{address, topic, {max_bn, max_i}, tracking_id}]}
    end
  end

  def mark_backfill_complete(tracking_id) do
    tracking_record = Repo.get_by(ContractEventTracking, id: tracking_id)

    tracking_record
    |> ContractEventTracking.changeset(%{backfilled: true, smart_contract_id: tracking_record.smart_contract_id})
    |> Repo.update()
  end

  @backfill_query """
  select lg.*
  from (select l.block_number, unnest(array_agg(l.index)) as index
        from logs l
        where l.first_topic = $1
          and l.address_hash = $2
          and (l.block_number, l.index) > ($3, $4)
        group by 1
        order by 1
        limit $5) s
           left join logs lg on lg.block_number = s.block_number and lg.index = s.index order by block_number, index;
  """
  def get_page_of_events(%Hash{} = contract_address, topic, {from_block_number, from_log_index}, page_size) do
    {:ok,address_bytes} = contract_address |> Address.dump()
    {:ok, result} = Telemetry.wrap(:backfill_page_fetch,
      SQL.query(Repo, @backfill_query, [topic, address_bytes, from_block_number, from_log_index, page_size])
    )

    #map raw results back into Explorer.Chain.Log structs
    result.rows
    |> Enum.map(&Repo.load(Log, {result.columns, &1}))
  end
end

