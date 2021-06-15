defmodule Explorer.Repo.Migrations.TransactionsStatAddGasUsageColumn do
  use Ecto.Migration

  def change do
    alter table(:transaction_stats) do
      add(:gas_used, :numeric, precision: 100, null: true)
    end
  end
end
