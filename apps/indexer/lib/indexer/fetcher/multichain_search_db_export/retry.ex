defmodule Indexer.Fetcher.MultichainSearchDbExport.Retry do
  @moduledoc """
  Retries exporting blockchain data to Multichain Search DB service.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Hash, MultichainSearchDbExportRetryQueue}
  alias Explorer.MicroserviceInterfaces.MultichainSearch

  alias Indexer.BufferedTask
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 10
  @failed_to_re_export_data_error "Batch export retry to the Multichain Search DB failed"

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
      MultichainSearchDbExportRetryQueue.stream_multichain_db_data_batch_to_retry_export(
        initial_acc,
        fn data, acc ->
          IndexerHelper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
        end
      )

    acc
  end

  @impl BufferedTask
  def run(export_data, _json_rpc_named_arguments) when is_list(export_data) do
    pre_prepared_export_data =
      export_data
      |> Enum.reduce(%{address_hashes: [], block_hashes: [], transactions: []}, fn %{
                                                                                     hash: hash_bytes,
                                                                                     hash_type: hash_type
                                                                                   },
                                                                                   acc ->
        case hash_type do
          :address ->
            Map.update(
              acc,
              :address_hashes,
              [%Hash{byte_count: 20, bytes: hash_bytes}],
              &[%Hash{byte_count: 20, bytes: hash_bytes} | &1]
            )

          :block ->
            Map.update(
              acc,
              :block_hashes,
              [%Hash{byte_count: 32, bytes: hash_bytes}],
              &[%Hash{byte_count: 32, bytes: hash_bytes} | &1]
            )

          :transaction ->
            Map.update(
              acc,
              :transactions,
              [%{hash: to_string(%Hash{byte_count: 32, bytes: hash_bytes})}],
              &[%{hash: to_string(%Hash{byte_count: 32, bytes: hash_bytes})} | &1]
            )
        end
      end)

    addresses =
      pre_prepared_export_data.address_hashes
      |> Chain.hashes_to_addresses()

    blocks =
      pre_prepared_export_data.block_hashes
      |> Block.by_hashes_query()
      |> Repo.all()

    prepared_export_data =
      pre_prepared_export_data
      |> Map.put(:addresses, addresses)
      |> Map.put(:blocks, blocks)
      |> Map.drop([:address_hashes])
      |> Map.drop([:block_hashes])

    case MultichainSearch.batch_import(prepared_export_data, true) do
      {:ok, _} ->
        export_data
        |> Enum.map(&Map.get(&1, :hash))
        |> MultichainSearchDbExportRetryQueue.by_hashes_query()
        |> Repo.delete_all()

      {:error, _} ->
        Logger.error(fn ->
          ["#{@failed_to_re_export_data_error}", "#{inspect(prepared_export_data)}"]
        end)
    end

    :ok
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
