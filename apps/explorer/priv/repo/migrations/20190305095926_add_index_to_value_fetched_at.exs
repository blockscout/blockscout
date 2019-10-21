defmodule Explorer.Repo.Migrations.AddIndexToValueFetchedAt do
  use Ecto.Migration

  def change do
    create(index(:address_coin_balances, [:value_fetched_at]))
  end
end
