defmodule Explorer.Repo.Migrations.DropOutdatedIndexForUnfetchedTokenBalances do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    execute("""
      DROP INDEX CONCURRENTLY IF EXISTS unfetched_address_token_balances_index;
    """)
  end
end
