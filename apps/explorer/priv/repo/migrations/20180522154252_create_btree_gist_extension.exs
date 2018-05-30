defmodule Explorer.Repo.Migrations.CreateBtreeGistExtension do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
  end
end
