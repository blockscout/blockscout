defmodule Explorer.Repo.Migrations.AddSecondaryCoinMarketHistory do
  use Ecto.Migration

  def change do
    alter table(:market_history) do
      add(:secondary_coin, :boolean, default: false)
    end

    drop_if_exists(unique_index(:market_history, [:date]))
    create(unique_index(:market_history, [:date, :secondary_coin]))
  end
end
