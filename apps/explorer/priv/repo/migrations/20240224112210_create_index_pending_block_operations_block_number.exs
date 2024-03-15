defmodule Explorer.Repo.Migrations.CreateIndexPendingBlockOperationsBlockNumber do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(index(:pending_block_operations, :block_number, concurrently: true))
  end
end
