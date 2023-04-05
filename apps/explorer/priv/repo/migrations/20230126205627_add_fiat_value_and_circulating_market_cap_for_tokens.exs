defmodule Explorer.Repo.Migrations.AddFiatValueAndCirculatingMarketCapForTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:fiat_value, :decimal)
      add(:circulating_market_cap, :decimal)
    end
  end
end
