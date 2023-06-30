defmodule Explorer.Repo.Migrations.AddMethodIdIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute("""
      CREATE INDEX CONCURRENTLY IF NOT EXISTS method_id ON public.transactions USING btree (substring(input for 4));
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS method_id")
  end
end
