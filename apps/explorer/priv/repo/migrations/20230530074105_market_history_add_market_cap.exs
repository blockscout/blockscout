defmodule Explorer.Repo.Migrations.MarketHistoryAddMarketCap do
  use Ecto.Migration

  def change do
    alter table(:market_history) do
      add(:market_cap, :decimal)
    end
  end
end
