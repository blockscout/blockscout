defmodule Explorer.Repo.Migrations.EnhancedUnfetchedTokenBalancesIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("""
      CREATE INDEX CONCURRENTLY unfetched_address_token_balances_index on address_token_balances(id)
      WHERE (
          ((address_hash != '\\x0000000000000000000000000000000000000000' AND token_type = 'ERC-721') OR token_type = 'ERC-20' OR token_type = 'ERC-1155') AND (value_fetched_at IS NULL OR value IS NULL)
      );
    """)
  end

  def down do
    execute("""
      DROP INDEX unfetched_address_token_balances_index;
    """)
  end
end
