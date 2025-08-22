defmodule Indexer.Fetcher.MultichainSearchDb.CountersExportQueue do
  @moduledoc """
  Exports blockchain data to Multichain Search DB service from the queue.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.MultichainSearchDb.CountersExportQueue
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo

  alias Indexer.{BufferedTask, Helper}

  @behaviour BufferedTask

  @default_max_batch_size 1000
  @default_max_concurrency 10
  @delete_queries_chunk_size 10
  @failed_to_export_data_error "Batch counters export attempt to the Multichain Search DB failed"
  @fetcher_name :multichain_search_db_counters_export_queue
  @queue_size_info "Queue size"
  @successfully_sent_info "Successfully sent"

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      CountersExportQueue.stream_multichain_db_counters_batch(
        initial_acc,
        fn data, acc ->
          Helper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run(items_from_db_queue, _) when is_list(items_from_db_queue) do
    case MultichainSearch.batch_export_counters(items_from_db_queue) do
      {:ok, {:chunks_processed, chunks}} ->
        chunks
        |> Enum.map(fn chunk -> chunk.counters end)
        |> List.flatten()
        |> Enum.map(&MultichainSearch.counter_http_item_to_queue_item(&1))
        |> delete_queue_items()
        |> log_queue_size()

      {:error, data_to_retry} ->
        Logger.error(fn ->
          ["#{@failed_to_export_data_error}", "#{inspect(data_to_retry.counters)}"]
        end)

        queue_items_to_retry =
          data_to_retry.counters
          |> Enum.map(&MultichainSearch.counter_http_item_to_queue_item(&1))

        items_from_db_queue
        |> Enum.reject(fn item_to_export ->
          Enum.any?(
            queue_items_to_retry,
            &(&1.timestamp == item_to_export.timestamp and &1.counter_type == item_to_export.counter_type)
          )
        end)
        |> delete_queue_items()
        |> log_queue_size()

        {:retry, queue_items_to_retry}
    end
  end

  # Removes items successfully sent to Multichain service from db queue.
  # The list is split into small chunks to prevent db deadlocks.
  #
  # ## Parameters
  # - `items`: The list of queue items to delete from the queue.
  #
  # ## Returns
  # - The `items` list.
  @spec delete_queue_items([map()]) :: [map()]
  defp delete_queue_items(items) do
    items
    |> Enum.chunk_every(@delete_queries_chunk_size)
    |> Enum.each(fn chunk_items ->
      chunk_items
      |> CountersExportQueue.delete_query()
      |> Repo.transaction()
    end)

    items
  end

  # Logs the number of the current queue size and the number of successfully sent items.
  #
  # ## Parameters
  # - `items_successful`: The list of items successfully sent to Multichain service.
  #
  # ## Returns
  # - `:ok`
  @spec log_queue_size(list()) :: any()
  defp log_queue_size(items_successful) do
    Logger.info(
      fn ->
        [
          "#{@queue_size_info}: ",
          "#{CountersExportQueue.queue_size()}, ",
          "#{@successfully_sent_info}: ",
          "#{Enum.count(items_successful)}"
        ]
      end,
      fetcher: @fetcher_name
    )
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
