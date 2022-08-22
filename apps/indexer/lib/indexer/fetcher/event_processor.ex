defmodule Indexer.Fetcher.EventProcessor do
  @moduledoc "Processes logs from tracked contracts and decodes into event parameters + inserts into DB"

  use Indexer.Fetcher
  use Spandex.Decorators
  require Logger
  require Indexer.Tracer

  alias Explorer.Celo.Events.Transformer
  alias Explorer.Celo.Telemetry
  alias Explorer.Chain
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Celo.TrackedEventCache
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 1,
    max_concurrency: 5,
    task_supervisor: Indexer.Fetcher.EventProcessor.TaskSupervisor,
    metadata: [fetcher: :event_processor]
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

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.EventProcessor.run/2", service: :indexer, tracer: Tracer)
  def run([{logs, function_selector, tracking_id}] = batch, _state) do
    decoded =
      logs
      |> Enum.map(fn log ->
        function_selector
        |> Transformer.decode_event(log)
        |> add_meta_properties(log, function_selector, tracking_id)
      end)

    imported =
      Chain.import(%{
        tracked_events: %{params: decoded},
        timeout: @import_timeout
      })

    case imported do
      {:ok, imported_items} ->
        Telemetry.event(:event_processor_ingested, %{
          tracked_contract_events: length(imported_items[:tracked_contract_events])
        })

        :ok

      {:error, step, reason, _changes} ->
        Logger.error("Failed to import tracked events  #{step} - #{inspect(reason)}")
        {:retry, batch}
    end
  end

  defp add_meta_properties(event_params, log, function_selector, tracking_id) do
    %{
      params: event_params,
      name: function_selector.function,
      contract_address_hash: log.address_hash,
      transaction_hash: log.transaction_hash,
      block_number: log.block_number,
      log_index: log.index,
      topic: log.first_topic,
      contract_event_tracking_id: tracking_id
    }
  end

  @doc "Accepts a list of maps representing events and filters out entries that have no corresponding `ContractEventTracking` row"
  def enqueue_logs(nil), do: :ok

  def enqueue_logs(events) when is_list(events) do
    events
    |> TrackedEventCache.batch_events()
    |> then(&BufferedTask.buffer(__MODULE__, &1))
  end
end
