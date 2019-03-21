defmodule Explorer.Repo.Migrations.AddInternalTransactionsIndexedAtToBlocks do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      # `null` when `internal_transactions` has never been fetched
      add(:internal_transactions_indexed_at, :utc_datetime_usec, null: true)
    end
  end
end
