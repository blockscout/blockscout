defmodule Explorer.Repo.Migrations.AddBlocksInsertedAtMinerHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :blocks,
        ~w(inserted_at miner_hash)a,
        concurrently: true
      )
    )
  end
end
