defmodule Explorer.Repo.Migrations.CreateIndexTokenTransfersTokenIds do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("""
    CREATE INDEX CONCURRENTLY token_transfers_token_ids_index on token_transfers USING GIN ("token_ids")
    """)
  end

  def down do
    execute("DROP INDEX token_transfers_token_ids_index")
  end
end
