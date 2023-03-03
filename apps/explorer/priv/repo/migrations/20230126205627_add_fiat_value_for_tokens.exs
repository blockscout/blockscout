defmodule Explorer.Repo.Migrations.AddFiatValueAndMarketCapForTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:fiat_value, :decimal)
      add(:market_cap, :decimal)
    end
  end
end
