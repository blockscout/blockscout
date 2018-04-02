defmodule Explorer.Repo.Migrations.CreateInternalTransactions do
  use Ecto.Migration

  def change do
    create table(:internal_transactions) do
      add :call_type, :string, null: false
      add :from_address_hash, :string
      add :gas, :numeric, precision: 100, null: false
      add :gas_used, :numeric, precision: 100, null: false
      add :index, :integer, null: false
      add :input, :text
      add :output, :text
      add :to_address_hash, :string
      add :trace_address, {:array, :integer}, null: false
      add :value, :numeric, precision: 100, null: false

      timestamps null: false

      # Foreign keys

      # TODO used in views, but not in indexer
      add :from_address_id, references(:addresses, on_delete: :delete_all), null: true
      # TODO used in views, but not in indexer
      add :to_address_id, references(:addresses, on_delete: :delete_all), null: true
      add :transaction_id, references(:transactions, on_delete: :delete_all), null: false
    end

    create index(:internal_transactions, :transaction_id)
    create index(:internal_transactions, :to_address_hash)
    create index(:internal_transactions, :from_address_hash)
  end
end
