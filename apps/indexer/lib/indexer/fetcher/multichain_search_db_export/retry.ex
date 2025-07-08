defmodule Indexer.Fetcher.MultichainSearchDbExport.Retry do
  @moduledoc """
  Retries exporting blockchain data to Multichain Search DB service.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Block, Hash, MultichainSearchDbExportRetryQueue, Transaction}
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
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run(data, _json_rpc_named_arguments) when is_list(data) do
    prepared_export_data = prepare_export_data(data)

    case MultichainSearch.batch_import(prepared_export_data) do
      {:ok, result} ->
        unless result == :service_disabled do
          hashes = all_hashes(prepared_export_data)

          hashes
          |> MultichainSearchDbExportRetryQueue.by_hashes_query()
          |> Repo.delete_all()
        end

        :ok

      {:error, data_to_retry} ->
        Logger.error(fn ->
          ["#{@failed_to_re_export_data_error}", "#{inspect(prepared_export_data)}"]
        end)

        hashes = all_hashes(prepared_export_data)
        failed_hashes = failed_hashes(data_to_retry)

        successful_hashes = hashes -- failed_hashes

        successful_hash_binaries =
          successful_hashes
          |> Enum.map(fn hash ->
            "0x" <> hex = hash
            Base.decode16!(hex, case: :mixed)
          end)

        successful_hash_binaries
        |> MultichainSearchDbExportRetryQueue.by_hashes_query()
        |> Repo.delete_all()

        {:retry, [data_to_retry]}
    end
  end

  defp all_hashes(prepared_export_data) do
    transaction_hashes =
      prepared_export_data[:transactions] |> Enum.map(&Map.get(&1, :hash))

    block_hashes = prepared_export_data[:blocks] |> Enum.map(&to_string(Map.get(&1, :hash)))

    address_hashes = prepared_export_data[:addresses] |> Enum.map(&to_string(Map.get(&1, :hash)))

    transaction_hashes ++ block_hashes ++ address_hashes
  end

  defp failed_hashes(data_to_retry) do
    block_transaction_hashes =
      data_to_retry.hashes
      |> Enum.map(&Map.get(&1, :hash))

    address_hashes =
      data_to_retry.addresses
      |> Enum.map(&Map.get(&1, :hash))

    block_transaction_hashes ++ address_hashes
  end

  @doc """
  Prepares export data by categorizing input hashes into addresses, blocks, and transactions,
  then enriches the result with resolved address and block data.

  ## Parameters

    - `export_data`: A list of maps, each containing a `:hash` (binary) and a `:hash_type` (`:address`, `:block`, or `:transaction`).

  ## Returns

    - A map containing:
      - `:addresses` - a list of resolved address structs from the given address hashes.
      - `:blocks` - a list of block structs fetched from the database using the block hashes or list of hash and hash_type maps.
      - `:transactions` - a list Transaction.t() objects or list of hash and hash_type maps.

  ## Example

      iex> prepare_export_data([
      ...>   %{hash: <<1,2,3>>, hash_type: :address},
      ...>   %{hash: <<4,5,6>>, hash_type: :block},
      ...>   %{hash: <<7,8,9>>, hash_type: :transaction}
      ...> ])
      %{
        addresses: [...],
        blocks: [...],
        transactions: [...]
      }

  """
  @spec prepare_export_data([%{hash: binary, hash_type: atom}]) :: %{
          addresses: [Address.t()],
          blocks: [Block.t() | %{hash: String.t(), hash_type: String.t()}],
          transactions: [Transaction.t() | %{hash: String.t(), hash_type: String.t()}]
        }
  def prepare_export_data(export_data) do
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

    pre_prepared_export_data
    |> Map.put(:addresses, addresses)
    |> Map.put(:blocks, blocks)
    |> Map.drop([:address_hashes])
    |> Map.drop([:block_hashes])
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
