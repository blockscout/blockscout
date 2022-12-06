defmodule Explorer.Repo.Migrations.ChangeIndexForPendingBlockOperations do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(
        :pending_block_operations,
        [:block_hash],
        name: "pending_block_operations_block_hash_index_partial",
        where: ~s("fetch_internal_transactions")
      )
    )

    create(index(:pending_block_operations, [:fetch_internal_transactions]))
  end
end
