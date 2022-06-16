defmodule Explorer.Repo.Migrations.DropBlocksMinerHashIndex do
  use Ecto.Migration

  def change do
    drop(constraint(:blocks, "blocks_miner_hash_fkey"))
  end
end
