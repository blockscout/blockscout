defmodule Explorer.Repo.Migrations.CreatePendingTransactionOperations do
  use Ecto.Migration

  def change do
    create table(:pending_transaction_operations, primary_key: false) do
      add(:transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      timestamps()
    end
  end
end
