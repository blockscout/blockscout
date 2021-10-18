defmodule Explorer.Repo.Migrations.AddBlocksInsertedAtMinerHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :public.blocks,
        ~w(inserted_at miner_hash)a,
        concurrently: true
      )
    )
  end
end
