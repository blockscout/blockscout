defmodule Explorer.Repo.Migrations.FillPendingBlockOperations do
  use Ecto.Migration

  def change do
  	execute("""
    INSERT INTO pending_block_operations
    (block_hash, inserted_at, updated_at, fetch_internal_transactions)
    SELECT b.hash, now(), now(), TRUE FROM blocks b
    WHERE b.internal_transactions_indexed_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM transactions t
      WHERE b.hash = t.block_hash
      AND t.internal_transactions_indexed_at IS NULL
    );
    """)
  end
end
