defmodule Explorer.Migrator.EmptyBytecodeForSelfdestructedSmartContracts do
  @moduledoc """
  Finds all existing selfdestruct internal transactions and empties the contract_code
  for addresses that still have bytecode, excluding contracts that were created and
  selfdestructed in the same transaction.

  This migration processes blocks from the head of the chain down to the first block,
  identifying selfdestruct operations and clearing the bytecode of affected contracts.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Address, Data, InternalTransaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Migrator.{FillingMigration, MigrationStatus}
  alias Explorer.Repo

  require Logger

  @migration_name "empty_bytecode_for_selfdestructed_smart_contracts"
  @empty_contract_code %Data{bytes: <<>>}

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"min_block_number" => min_block_number} = state)
      when not is_nil(min_block_number) and min_block_number < 0 do
    {[], state}
  end

  def last_unprocessed_identifiers(%{"min_block_number" => min_block_number} = state)
      when not is_nil(min_block_number) do
    limit = batch_size() * concurrency()
    from_block_number = min_block_number
    to_block_number = max(from_block_number - limit + 1, 0)

    block_numbers = Enum.to_list(from_block_number..to_block_number//-1)

    {block_numbers, %{state | "min_block_number" => to_block_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    query =
      from(
        migration_status in MigrationStatus,
        where: migration_status.migration_name == ^@migration_name,
        select: migration_status.meta
      )

    meta = Repo.one(query, timeout: :infinity)

    state
    |> Map.put("min_block_number", (meta && meta["min_block_number"]) || BlockNumber.get_max())
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    if Enum.empty?(block_numbers) do
      {:ok, []}
    else
      # Find all selfdestruct internal transactions in these blocks
      selfdestruct_query =
        from(
          it in InternalTransaction,
          where: it.block_number in ^block_numbers,
          where: it.type == :selfdestruct,
          select: %{
            transaction_hash: it.transaction_hash,
            from_address_hash: it.from_address_hash,
            block_number: it.block_number
          }
        )

      selfdestruct_transactions = Repo.all(selfdestruct_query, timeout: :infinity)

      if Enum.empty?(selfdestruct_transactions) do
        {:ok, []}
      else
        # Get unique transaction hashes to check for create/create2
        transaction_hashes =
          selfdestruct_transactions
          |> Enum.map(& &1.transaction_hash)
          |> Enum.uniq()

        # Find all create/create2 internal transactions in the same transactions
        create_query =
          from(
            it in InternalTransaction,
            where: it.transaction_hash in ^transaction_hashes,
            where: it.type in [:create, :create2],
            select: %{
              transaction_hash: it.transaction_hash,
              created_contract_address_hash: it.created_contract_address_hash
            }
          )

        created_contracts = Repo.all(create_query, timeout: :infinity)

        # Build a set of {transaction_hash, address_hash} for contracts created in same tx
        created_in_same_tx =
          created_contracts
          |> Enum.map(&{&1.transaction_hash, &1.created_contract_address_hash})
          |> MapSet.new()

        # Filter to find addresses that were selfdestructed but NOT created in the same transaction
        addresses_to_empty =
          selfdestruct_transactions
          |> Enum.reject(fn sd ->
            MapSet.member?(created_in_same_tx, {sd.transaction_hash, sd.from_address_hash})
          end)
          |> Enum.map(& &1.from_address_hash)
          |> Enum.uniq()

        if Enum.empty?(addresses_to_empty) do
          {:ok, []}
        else
          # Only update addresses that still have non-empty contract_code
          update_query =
            from(
              address in Address,
              where: address.hash in ^addresses_to_empty,
              where: not is_nil(address.contract_code),
              where: fragment("octet_length(?) > 0", address.contract_code),
              update: [set: [contract_code: ^@empty_contract_code]],
              select: address.hash
            )

          {count, updated_hashes} = Repo.update_all(update_query, [], timeout: :infinity)

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if count > 0 do
            Logger.info(
              "Emptied contract_code for #{count} selfdestructed contracts in blocks #{inspect(block_numbers)}: #{inspect(updated_hashes, limit: :infinity)}"
            )
          end

          {:ok, count}
        end
      end
    end
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
