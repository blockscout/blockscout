defmodule Explorer.Migrator.ShrinkInternalTransactions do
  @moduledoc """
  Removes the content of output field and leaves first 4 bytes signature in input field in internal transactions.
  This migration is disabled unless SHRINK_INTERNAL_TRANSACTIONS_ENABLED env variable is set to true.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "shrink_internal_transactions"

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
        where: fragment("length(?) > 4", it.input) or not is_nil(it.output),
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
    block_hashes_query = from(b in Block, where: b.number in ^block_numbers, select: b.hash)

    query =
      from(it in InternalTransaction,
        where: it.block_hash in subquery(block_hashes_query),
        update: [set: [input: fragment("substring(? FOR 4)", it.input), output: nil]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
