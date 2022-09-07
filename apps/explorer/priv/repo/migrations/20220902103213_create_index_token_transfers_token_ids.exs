defmodule Explorer.Repo.Migrations.CreateIndexTokenTransfersTokenIds do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX token_transfers_token_ids_index on token_transfers USING GIN ("token_ids")
    """)
  end

  def down do
    execute("DROP INDEX token_transfers_token_ids_index")
  end
end
