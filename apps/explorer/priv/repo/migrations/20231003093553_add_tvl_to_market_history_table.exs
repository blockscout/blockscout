defmodule Explorer.Repo.Migrations.AddTvlToMarketHistoryTable do
  use Ecto.Migration

  def change do
    alter table(:market_history) do
      add(:tvl, :decimal)
    end
  end
end
