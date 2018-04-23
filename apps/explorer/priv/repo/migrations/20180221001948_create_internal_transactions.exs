defmodule Explorer.Repo.Migrations.CreateInternalTransactions do
  use Ecto.Migration

  def change do
    create table(:internal_transactions) do
      add(:call_type, :string, null: false)
      add(:gas, :numeric, precision: 100, null: false)
      add(:gas_used, :numeric, precision: 100, null: false)
      add(:index, :integer, null: false)
      add(:input, :text)
      add(:output, :text)
      add(:trace_address, {:array, :integer}, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false)

      # Foreign keys

      add(:from_address_hash, references(:addresses, column: :hash, type: :bytea))
      add(:to_address_hash, references(:addresses, column: :hash, type: :bytea))

      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    # Foreign Key indexes

    create(index(:internal_transactions, :from_address_hash))
    create(index(:internal_transactions, :to_address_hash))
    create(index(:internal_transactions, :transaction_hash))
  end
end
