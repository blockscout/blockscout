defmodule Explorer.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      # Fields

      add(:gas, :numeric, precision: 100, null: false)
      add(:gas_price, :numeric, precision: 100, null: false)
      add(:hash, :bytea, null: false, primary_key: true)

      # `null` when a pending transaction
      add(:index, :integer, null: true)

      add(:input, :text, null: false)
      add(:nonce, :integer, null: false)
      add(:public_key, :string, null: false)
      add(:r, :string, null: false)
      add(:s, :string, null: false)
      add(:standard_v, :string, null: false)
      add(:v, :string, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false)

      # Foreign Keys

      # `null` when a pending transaction
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)

      add(:from_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      # `null` when it is a contract creation transaction
      add(:to_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
    end

    # Foreign Key indexes

    create(index(:transactions, :block_hash))
    create(index(:transactions, :from_address_hash))
    create(index(:transactions, :to_address_hash))

    # Search indexes

    create(index(:transactions, :inserted_at))
    create(index(:transactions, :updated_at))

    # Unique indexes

    create(unique_index(:transactions, [:block_hash, :index]))
  end
end
