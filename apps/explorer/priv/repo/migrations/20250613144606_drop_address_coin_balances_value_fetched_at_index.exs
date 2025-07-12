defmodule Explorer.Repo.Migrations.DropAddressCoinBalancesValueFetchedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists(index(:address_coin_balances, [:value_fetched_at], concurrently: true))
  end
end
