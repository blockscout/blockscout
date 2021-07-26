defmodule Explorer.Repo.Migrations.AddExchangeRateColumnToBridgedTokens do
  use Ecto.Migration

  def change do
    alter table("bridged_tokens") do
      add(:exchange_rate, :decimal)
    end
  end
end
