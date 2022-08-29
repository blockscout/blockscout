defmodule Indexer.Fetcher.EventBackfill do
  @moduledoc "Fetch historical and missing events for the event processor"

  use Indexer.Fetcher
  require Logger

  alias Explorer.Celo.Events.Transformer
  alias Explorer.Celo.Telemetry
  alias Explorer.Chain
  alias Explorer.Chain.Log
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Celo.TrackedEventCache
  alias Indexer.Fetcher.Util

  use BufferedTask
  import Ecto.Query

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 1,
    max_concurrency: 2,
    dedup_entries: true,
    task_supervisor: Indexer.Fetcher.EventBackfill.TaskSupervisor,
    metadata: [fetcher: :event_backfill]
  ]

  @import_timeout 60_000

  @impl BufferedTask
  def init(initial, _reducer, _) do
    initial
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options
    |> Keyword.merge(@defaults)
    |> Util.default_child_spec(gen_server_options, __MODULE__)
  end

  #deduplicates entries based on the contract address and topic
  @impl BufferedTask
  def dedup_entries( %BufferedTask{dedup_entries: true, task_ref_to_batch: task_ref_to_batch, bound_queue: bound_queue} = task, entries) do
    contract_address_and_topic = fn {ct, _progress, _strategy} -> ct end

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

  def missing_events_query({contract_address, topic}, {block_number, log_index} \\ {0,0}) do
    Log
    |> from(
      inner_join: ccc in "celo_core_contracts",
      on: ccc.address_hash == l.address_hash,
      select: %{
        first_topic: l.first_topic,
        second_topic: l.second_topic,
        third_topic: l.third_topic,
        fourth_topic: l.fourth_topic,
        data: l.data,
        address_hash: l.address_hash,
        transaction_hash: l.transaction_hash,
        block_number: l.block_number,
        index: l.index
      },
      where: l.first_topic == ^topic and {l.block_number, l.index} > {^block_number, ^index},
      order_by: [asc: l.block_number, asc: l.index],
      limit: @batch_size
    )

  end
end

