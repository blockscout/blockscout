defmodule Explorer.Repo.Migrations.AddMethodIdIndex do
  use Ecto.Migration

  def up do
    execute("""
      CREATE INDEX method_id ON public.transactions USING btree (substring(input for 4));
    """)
  end

  def down do
    execute("DROP INDEX method_id")
  end
end
