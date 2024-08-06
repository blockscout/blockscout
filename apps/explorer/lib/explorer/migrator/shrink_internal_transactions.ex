defmodule Explorer.Migrator.ShrinkInternalTransactions do
  @moduledoc """
  Removes the content of input and output fields in internal transactions.
  This migration is disabled unless SHRINK_INTERNAL_TRANSACTIONS_ENABLED env variable is set to true.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "shrink_internal_transactions"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers do
    limit = batch_size() * concurrency()

    unprocessed_data_query()
    |> select([it], {it.block_hash, it.block_index})
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(it in InternalTransaction, where: fragment("length(?) > 4", it.input) or not is_nil(it.output))
  end

  @impl FillingMigration
  def update_batch(internal_transaction_ids) do
    internal_transaction_ids
    |> build_update_query()
    |> Repo.query!([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp build_update_query(internal_transaction_ids) do
    encoded_ids =
      internal_transaction_ids
      |> Enum.reduce("", fn {block_hash, block_index}, acc ->
        acc <> "('\\#{String.trim_leading(to_string(block_hash), "0")}', #{block_index}),"
      end)
      |> String.trim_trailing(",")

    """
    UPDATE internal_transactions
    SET input = substring(input FOR 4), output = NULL
    WHERE (block_hash, block_index) IN (#{encoded_ids});
    """
  end
end
