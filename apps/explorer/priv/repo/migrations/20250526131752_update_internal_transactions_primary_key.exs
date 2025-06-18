defmodule Explorer.Repo.Migrations.UpdateInternalTransactionsPrimaryKey do
  use Ecto.Migration

  def up do
    create_if_not_exists(unique_index(:internal_transactions, [:block_hash, :transaction_index, :index]))
    drop(constraint(:internal_transactions, :internal_transactions_pkey))

    execute(
      "ALTER INDEX internal_transactions_block_hash_transaction_index_index_index RENAME TO internal_transactions_pkey"
    )

    execute("ALTER TABLE internal_transactions ADD PRIMARY KEY USING INDEX internal_transactions_pkey")
    execute("ALTER TABLE internal_transactions ALTER COLUMN block_index DROP NOT NULL")
  end

  def down do
    drop(constraint(:internal_transactions, :internal_transactions_pkey))
    execute("ALTER TABLE internal_transactions ADD PRIMARY KEY (block_hash, block_index)")
  end
end
