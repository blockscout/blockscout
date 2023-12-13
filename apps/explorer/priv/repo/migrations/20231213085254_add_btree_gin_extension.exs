defmodule Explorer.Repo.Migrations.CreateBtreeGinExtension do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS btree_gin")
  end

  def down do
    execute("DROP EXTENSION IF EXISTS btree_gin")
  end
end
