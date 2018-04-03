defmodule Explorer.Repo.Migrations.CreateReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts) do
      add :transaction_id, references(:transactions), null: false
      add :cumulative_gas_used, :numeric, precision: 100, null: false
      add :gas_used, :numeric, precision: 100, null: false
      add :status, :integer, null: false
      add :index, :integer, null: false
      timestamps null: false
    end

    create index(:receipts, :index)
    create index(:receipts, :status)
    create unique_index(:receipts, :transaction_id)
  end
end
