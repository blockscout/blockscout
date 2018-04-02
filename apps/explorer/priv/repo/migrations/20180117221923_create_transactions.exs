defmodule Explorer.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      # Fields
      add :gas, :numeric, precision: 100, null: false
      add :gas_price, :numeric, precision: 100, null: false
      add :hash, :string, null: false
      add :input, :text, null: false
      add :nonce, :integer, null: false
      add :public_key, :string, null: false
      add :r, :string, null: false
      add :s, :string, null: false
      add :standard_v, :string, null: false
      add :transaction_index, :string, null: false
      add :v, :string, null: false
      add :value, :numeric, precision: 100, null: false

      timestamps null: false

      # Foreign Keys

      # null when a pending transaction
      add :block_id, references(:blocks, on_delete: :delete_all), null: true
      add :from_address_id, references(:addresses, on_delete: :delete_all)
      add :to_address_id, references(:addresses, on_delete: :delete_all)
    end

    create index(:transactions, :block_id)
    create index(:transactions, :from_address_id)
    create unique_index(:transactions, [:hash])
    create index(:transactions, :inserted_at)
    create index(:transactions, :to_address_id)
    create index(:transactions, :updated_at)
  end
end
