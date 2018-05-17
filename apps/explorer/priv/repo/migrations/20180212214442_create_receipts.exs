defmodule Explorer.Repo.Migrations.CreateReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts, primary_key: false) do
      add(:cumulative_gas_used, :numeric, precision: 100, null: false)
      add(:gas_used, :numeric, precision: 100, null: false)
      # add(:status, :integer, null: false)
      add(:transaction_index, :integer, null: false)

      timestamps(null: false)

      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    # create(index(:receipts, :status))
    create(index(:receipts, :transaction_index))
    create(unique_index(:receipts, :transaction_hash))
  end
end
