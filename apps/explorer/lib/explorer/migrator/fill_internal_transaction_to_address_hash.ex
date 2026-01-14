defmodule Explorer.Migrator.FillInternalTransactionToAddressHashWithCreatedContractAddressHash do
  @moduledoc """
  Fills `to_address_hash` column with the data from `created_contract_address_hash`
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "fill_internal_transaction_to_address_hash_with_created_contract_address_hash"

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
        it in InternalTransaction,
        where: not is_nil(it.created_contract_address_hash),
        where: is_nil(it.to_address_hash),
        select: max(it.block_number)
      )

    max_block_number = Repo.one(query, timeout: :infinity)

    state
    |> Map.put("max_block_number", max_block_number || -1)
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    query =
      from(it in InternalTransaction,
        where: it.block_number in ^block_numbers,
        where: not is_nil(it.created_contract_address_hash),
        where: is_nil(it.to_address_hash),
        update: [set: [to_address_hash: it.created_contract_address_hash]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_fill_internal_transaction_to_address_hash_with_created_contract_address_hash_finished(true)
  end
end
