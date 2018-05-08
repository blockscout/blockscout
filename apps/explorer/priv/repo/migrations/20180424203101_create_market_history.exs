defmodule Explorer.Repo.Migrations.CreateMarketHistory do
  use Ecto.Migration

  def change do
    create table(:market_history) do
      add(:date, :date)
      add(:closing_price, :decimal)
      add(:opening_price, :decimal)
    end

    create(unique_index(:market_history, :date))
  end
end
