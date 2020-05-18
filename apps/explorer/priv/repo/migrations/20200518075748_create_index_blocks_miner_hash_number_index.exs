defmodule Explorer.Repo.Migrations.CreateIndexBlocksMinerHashNumberIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:blocks, [:miner_hash, :number]))
  end
end
