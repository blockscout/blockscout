defmodule Explorer.Repo.Migrations.AddIndexOnFetchedCoinBalanceToAddresses do
  use Ecto.Migration

  def change do
    create(index(:addresses, [:fetched_coin_balance]))
  end
end
