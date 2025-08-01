defmodule Explorer.Repo.Migrations.CreateNeonSolanaTransactions do
  use Ecto.Migration

  def change do
    create table(:neon_linked_solana_transactions) do
      add(:neon_transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:solana_transaction_hash, :string, null: false)
      timestamps()
    end

    create(unique_index(:neon_linked_solana_transactions, [:neon_transaction_hash, :solana_transaction_hash]))
  end
end
