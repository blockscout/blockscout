defmodule Explorer.Migrator.BackfillMultichainSearchDB do
  @moduledoc """
  Copies existing data from Blockscout instance to Multichain Search DB instance.
  """

  require Logger

  use Explorer.Migrator.FillingMigration

  alias Explorer.Chain.{Address, Block, InternalTransaction, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.{BackgroundMigrations, BlockNumber}
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Migrator.FillingMigration

  import Ecto.Query

  @migration_name "backfill_multichain_search_db"

  @failed_to_fetch_data_error "Failed to fetch data from the Blockscout DB for batch export to the Multichain Search DB"
  @failed_to_export_data_error "Batch export to the Multichain Search DB failed"
  @for " for block numbers "

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(%{"max_block_number" => from_block_number} = state) do
    limit = batch_size() * concurrency()
    to_block_number = max(from_block_number - limit + 1, 0)

    {Enum.to_list(from_block_number..to_block_number), %{state | "max_block_number" => to_block_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    query =
      from(
        migration_status in MigrationStatus,
        where: migration_status.migration_name == @migration_name,
        select: migration_status.meta
      )

    meta = Repo.one(query, timeout: :infinity)

    state
    |> Map.put("max_block_number", (meta && meta["max_block_number"]) || BlockNumber.get_max())
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    blocks_query = from(block in Block, where: block.number in ^block_numbers)

    blocks_preloads = [:miner]

    blocks_task =
      Task.async(fn ->
        blocks_query
        |> preload(^blocks_preloads)
        |> Repo.all(timeout: :infinity)
      end)

    case Task.yield(blocks_task, :infinity) do
      {:ok, blocks} ->
        transaction_preloads = [:from_address, :to_address, :created_contract_address]

        transactions_query = from(transaction in Transaction, where: transaction.block_number in ^block_numbers)

        transactions_task =
          Task.async(fn ->
            transactions_query
            |> preload(^transaction_preloads)
            |> Repo.all(timeout: :infinity)
          end)

        block_hashes = blocks |> Enum.map(& &1.hash)

        internal_transactions_query =
          from(internal_transaction in InternalTransaction, where: internal_transaction.block_hash in ^block_hashes)

        internal_transactions_task =
          Task.async(fn ->
            internal_transactions_query
            |> preload(^transaction_preloads)
            |> Repo.all(timeout: :infinity)
          end)

        token_transfer_preloads = [:from_address, :to_address, :token_contract_address]

        token_transfers_query =
          from(token_transfer in TokenTransfer, where: token_transfer.block_number in ^block_numbers)

        token_transfers_task =
          Task.async(fn ->
            token_transfers_query
            |> preload(^token_transfer_preloads)
            |> Repo.all(timeout: :infinity)
          end)

        tasks = [
          transactions_task,
          internal_transactions_task,
          token_transfers_task
        ]

        case tasks
             |> Task.yield_many(:infinity) do
          [
            {_transactions_task, {:ok, transactions}},
            {_internal_transactions_task, {:ok, internal_transactions}},
            {_token_transfers_task, {:ok, token_transfers}}
          ] ->
            addresses =
              [
                transactions,
                internal_transactions,
                token_transfers,
                blocks
              ]
              |> List.flatten()
              |> Enum.reduce([], fn result, addresses_acc ->
                # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                extract_address_from_result(result) ++ addresses_acc
              end)
              |> Enum.uniq()
              |> Enum.reject(&is_nil/1)

            to_import = %{
              addresses: addresses,
              blocks: blocks,
              transactions: transactions
            }

            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case MultichainSearch.batch_import(to_import) do
              {:ok, _} = result ->
                result

              {:error, _} ->
                Logger.error(fn ->
                  ["#{@failed_to_export_data_error}", "#{@for}", "#{inspect(block_numbers)}"]
                end)

                :timer.sleep(1000)

                update_batch(block_numbers)
            end

          _ ->
            repeat_block_numbers_processing_on_error(block_numbers)
        end

      _ ->
        repeat_block_numbers_processing_on_error(block_numbers)
    end
  end

  defp repeat_block_numbers_processing_on_error(block_numbers) do
    Logger.error(fn ->
      ["#{@failed_to_fetch_data_error}", "#{@for}", "#{inspect(block_numbers)}"]
    end)

    :timer.sleep(1000)

    update_batch(block_numbers)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_backfill_multichain_search_db_finished(true)
  end

  @spec extract_address_from_result(Transaction.t() | InternalTransaction.t() | TokenTransfer.t() | Block.t()) :: [
          Address.t()
        ]
  defp extract_address_from_result(result) do
    case result do
      %Transaction{} ->
        [result.from_address, result.to_address, result.created_contract_address]

      %InternalTransaction{} ->
        [result.from_address, result.to_address, result.created_contract_address]

      %TokenTransfer{} ->
        [result.from_address, result.to_address, result.token_contract_address]

      %Block{} ->
        [result.miner]
    end
  end
end
