defmodule Explorer.Repo.Migrations.AddAddressCurrentTokenBalancesOrderingIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :address_current_token_balances,
        [:value, :address_hash],
        concurrently: true
      )
    )
  end
end
