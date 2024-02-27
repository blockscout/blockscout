defmodule Explorer.Repo.Migrations.AddSmartContractsNameTextIndex do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS smart_contracts_trgm_idx ON smart_contracts USING GIN (to_tsvector('english', name))
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS smart_contracts_trgm_idx")
  end
end
