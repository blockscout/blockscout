defmodule Explorer.Repo.Migrations.AddBlocksDateIndex do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX IF NOT EXISTS blocks_date ON blocks(date(timestamp), number);")
  end

  def down do
    execute("DROP INDEX IF EXISTS blocks_date;")
  end
end
