defmodule Indexer.Fetcher.MultichainSearchDb.MainExportQueue do
  @moduledoc """
  Exports blockchain data to Multichain Search DB service from the queue.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash, MultichainSearchDb.MainExportQueue, Transaction}
  alias Explorer.MicroserviceInterfaces.MultichainSearch

  alias Indexer.BufferedTask
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  @default_max_batch_size 1000
  @default_max_concurrency 10
  @failed_to_re_export_data_error "Batch main export retry to the Multichain Search DB failed"

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
      MainExportQueue.stream_multichain_db_data_batch(
        initial_acc,
        fn data, acc ->
          IndexerHelper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run(
        %{
          addresses: _addresses,
          transactions: _transactions,
          block_ranges: _block_ranges,
          block_hashes: _block_hashes
        } = prepared_export_data,
        _json_rpc_named_arguments
      ) do
    export_data_to_multichain(prepared_export_data)
  end

  @impl BufferedTask
  def run(data, _json_rpc_named_arguments) when is_list(data) do
    prepared_export_data = prepare_export_data(data)

    export_data_to_multichain(prepared_export_data)
  end

  defp export_data_to_multichain(prepared_export_data) do
    case MultichainSearch.batch_import(prepared_export_data) do
      {:ok, {:chunks_processed, result}} ->
        all_hashes =
          result
          |> Enum.flat_map(fn params ->
            hashes = prepare_hashes_for_db_query(params[:hashes], :full)
            addresses = prepare_hashes_for_db_query(params[:addresses], :address)

            hashes ++ addresses
          end)

        all_hashes
        |> MainExportQueue.by_hashes_query()
        |> Repo.delete_all()

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
        |> MainExportQueue.by_hashes_query()
        |> Repo.delete_all()

        {:retry, data_to_retry}
    end
  end

  defp prepare_hashes_for_db_query(entities, entity_type) do
    entities
    |> Enum.map(fn entity ->
      fun = if entity_type == :address, do: :string_to_address_hash, else: :string_to_full_hash

      case apply(Chain, fun, [Map.get(entity, :hash)]) do
        {:ok, hash} -> hash.bytes
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp all_hashes(prepared_export_data) do
    transaction_hashes =
      prepared_export_data[:transactions] |> Enum.map(&Map.get(&1, :hash))

    block_hashes = prepared_export_data[:block_hashes] |> Enum.map(&to_string(&1))

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
  Prepares export data from a list of maps containing `:hash`, `:hash_type`, and `:block_range` keys.

  Processes each entry by its `:hash_type` (`:address`, `:block`, or `:transaction`), accumulating the corresponding hashes and block ranges.
  Converts address hashes to address structs and returns a map with the following keys:

    - `:addresses` - a list of `Address.t()` structs derived from address hashes.
    - `:transactions` - a list of `Transaction.t()` structs or maps with transaction hash and hash type.
    - `:block_ranges` - a list of maps with `:min_block_number` and `:max_block_number` as strings.
    - `:block_hashes` - a list of `Hash.t()` structs for block hashes.

  ## Parameters

    - `export_data`: a list of maps, each containing:
      - `:hash` (binary): the hash value.
      - `:hash_type` (atom): the type of hash (`:address`, `:block`, or `:transaction`).
      - `:block_range` (any): the block range associated with the hash.

  ## Returns

  A map with prepared export data, including addresses, transactions, block ranges, and block hashes.
  """
  @spec prepare_export_data([%{hash: binary(), hash_type: atom(), block_range: any()}]) :: %{
          addresses: [Address.t()],
          transactions: [Transaction.t() | %{hash: String.t(), hash_type: String.t()}],
          block_ranges: [%{min_block_number: String.t(), max_block_number: String.t()}],
          block_hashes: [Hash.t()]
        }
  def prepare_export_data(export_data) do
    pre_prepared_export_data =
      export_data
      |> Enum.reduce(
        %{
          address_hashes: [],
          block_hashes: [],
          transactions: [],
          block_ranges: [
            %{
              min_block_number: nil,
              max_block_number: nil
            }
          ]
        },
        fn res, acc ->
          case res.hash_type do
            :address ->
              acc
              |> Map.update(
                :address_hashes,
                [%Hash{byte_count: 20, bytes: res.hash}],
                &[%Hash{byte_count: 20, bytes: res.hash} | &1]
              )
              |> maybe_update_block_ranges_in_params_map(res.block_range)

            :block ->
              acc
              |> Map.update(
                :block_hashes,
                [%Hash{byte_count: 32, bytes: res.hash}],
                &[%Hash{byte_count: 32, bytes: res.hash} | &1]
              )
              |> maybe_update_block_ranges_in_params_map(res.block_range)

            :transaction ->
              acc
              |> Map.update(
                :transactions,
                [%{hash: to_string(%Hash{byte_count: 32, bytes: res.hash})}],
                &[%{hash: to_string(%Hash{byte_count: 32, bytes: res.hash})} | &1]
              )
              |> maybe_update_block_ranges_in_params_map(res.block_range)
          end
        end
      )

    addresses =
      pre_prepared_export_data.address_hashes
      |> Chain.hashes_to_addresses()

    pre_prepared_export_data
    |> Map.put(:addresses, addresses)
    |> Map.drop([:address_hashes])
    |> (&if(
          Map.get(&1, :block_ranges) == [
            %{
              max_block_number: nil,
              min_block_number: nil
            }
          ],
          do: Map.drop(&1, [:block_ranges]),
          else: &1
        )).()
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end

  defp maybe_update_block_ranges_in_params_map(params_map, nil), do: params_map

  defp maybe_update_block_ranges_in_params_map(params_map, block_range) do
    params_map
    |> Map.update!(
      :block_ranges,
      &[
        %{
          min_block_number: to_string(min(block_range.from, parse_block_number(&1, :min_block_number))),
          max_block_number: to_string(max(block_range.to, parse_block_number(&1, :max_block_number)))
        }
      ]
    )
  end

  defp parse_block_number(nil, _), do: 0

  defp parse_block_number([%{min_block_number: nil}], :min_block_number), do: nil

  defp parse_block_number([%{max_block_number: nil}], :max_block_number), do: 0

  defp parse_block_number(
         [
           %{
             min_block_number: _,
             max_block_number: _
           } = block_range
         ],
         type
       ) do
    case Integer.parse(block_range[type]) do
      {num, _} -> num
      :error -> 0
    end
  end
end
