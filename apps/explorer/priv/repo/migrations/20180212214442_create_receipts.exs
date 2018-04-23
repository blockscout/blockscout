defmodule Explorer.Repo.Migrations.CreateReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts) do
      add(:cumulative_gas_used, :numeric, precision: 100, null: false)
      add(:gas_used, :numeric, precision: 100, null: false)
      add(:index, :integer, null: false)
      add(:status, :integer, null: false)

      timestamps(null: false)

      # Foreign keys

      add(:receipt_id, references(:receipts, on_delete: :delete_all), null: true)

      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    create(index(:receipts, :index))
    create(index(:receipts, :status))
    create(unique_index(:receipts, :transaction_hash))
  end
end
