defmodule Explorer.Migrator.BackfillCallTypeEnum do
  @moduledoc """
  Fills `call_type_enum` field in `internal_transactions`.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "backfill_call_type_enum"

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
        where: is_nil(it.call_type_enum) and not is_nil(it.call_type),
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
        where: it.block_hash in subquery(block_hashes_query) and is_nil(it.call_type_enum) and not is_nil(it.call_type),
        update: [set: [call_type_enum: fragment("?::internal_transactions_call_type", it.call_type), call_type: nil]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_backfill_call_type_enum_finished(true)
  end
end
