defmodule Explorer.Repo.Migrations.PendingTransactions do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX IF NOT EXISTS pending_txs_index ON transactions(inserted_at, hash) WHERE (block_hash IS NULL AND (error IS NULL OR (error != 'dropped/replaced')))"
    )

    drop_if_exists(index(:transactions, [:hash, :inserted_at], name: "transactions_hash_inserted_at_index"))
  end

  def down do
    execute("DROP INDEX IF EXISTS pending_txs_index")
    create_if_not_exists(index(:transactions, [:hash, :inserted_at]))
  end
end
