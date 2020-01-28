defmodule Explorer.Repo.Migrations.PendingBlockOperationsBlockHashPartialIndex do
  use Ecto.Migration

  def change do
    execute(
      "CREATE INDEX pending_block_operations_block_hash_index_partial ON pending_block_operations(block_hash) WHERE fetch_internal_transactions=true;"
    )
  end
end
