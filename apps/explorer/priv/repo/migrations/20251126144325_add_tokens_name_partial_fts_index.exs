defmodule Explorer.Repo.Migrations.AddTokensNamePartialFtsIndex do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX tokens_name_partial_fts_index ON tokens USING GIN (to_tsvector('english', name)) WHERE symbol IS NULL
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS tokens_name_partial_fts_index")
  end
end
