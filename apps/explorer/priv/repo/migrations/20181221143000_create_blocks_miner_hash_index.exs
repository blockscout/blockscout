defmodule Explorer.Repo.Migrations.CreateBlocksMinerHashIndex do
  use Ecto.Migration

  def change do
    create(index(:blocks, [:miner_hash]))
  end
end
