defmodule Explorer.Repo.Migrations.RemoveInternalTransactionsTransactionHashNotNull do
  use Ecto.Migration

  def change do
    alter table(:internal_transactions) do
      modify(:transaction_hash, :bytea, null: true)
    end
  end
end
