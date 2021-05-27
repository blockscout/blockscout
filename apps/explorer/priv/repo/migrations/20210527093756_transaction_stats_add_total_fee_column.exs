defmodule Explorer.Repo.Migrations.TransactionStatsAddTotalFeeColumn do
  use Ecto.Migration

  def change do
    alter table(:transaction_stats) do
      add(:total_fee, :numeric, precision: 100, null: true)
    end
  end
end
