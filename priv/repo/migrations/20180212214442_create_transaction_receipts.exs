defmodule Explorer.Repo.Migrations.CreateTransactionReceipts do
  use Ecto.Migration

  def change do
    create table(:transaction_receipts) do
      add :transaction_id, references(:transactions), null: false
      add :cumulative_gas_used, :numeric, precision: 100, null: false
      add :gas_used, :numeric, precision: 100, null: false
      add :status, :integer, null: false
      add :index, :integer, null: false
      timestamps null: false
    end

    create index(:transaction_receipts, :index)
    create unique_index(:transaction_receipts, [:transaction_id, :index])
  end
end
