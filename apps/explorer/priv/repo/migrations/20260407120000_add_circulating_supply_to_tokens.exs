defmodule Explorer.Repo.Migrations.AddCirculatingSupplyToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:circulating_supply, :decimal)
    end
  end
end
