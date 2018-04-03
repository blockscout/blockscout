defmodule Explorer.Repo.Migrations.DedupInternalTransactions do
  use Ecto.Migration

  def up do
    execute "SELECT DISTINCT ON (transaction_id, index) * INTO internal_transactions_dedup FROM internal_transactions;"
    execute "DROP TABLE internal_transactions;"
    execute "ALTER TABLE internal_transactions_dedup RENAME TO internal_transactions;"
    execute "CREATE SEQUENCE internal_transactions_id_seq OWNED BY internal_transactions.id;"
    execute """
      ALTER TABLE internal_transactions
        ALTER COLUMN id SET DEFAULT nextval('internal_transactions_id_seq'),
        ALTER COLUMN id SET NOT NULL,
        ALTER COLUMN transaction_id SET NOT NULL,
        ALTER COLUMN to_address_id SET NOT NULL,
        ALTER COLUMN from_address_id SET NOT NULL,
        ALTER COLUMN index SET NOT NULL,
        ALTER COLUMN call_type SET NOT NULL,
        ALTER COLUMN trace_address SET NOT NULL,
        ALTER COLUMN value SET NOT NULL,
        ALTER COLUMN gas SET NOT NULL,
        ALTER COLUMN gas_used SET NOT NULL,
        ALTER COLUMN inserted_at SET NOT NULL,
        ALTER COLUMN updated_at SET NOT NULL,
        ADD FOREIGN KEY (from_address_id) REFERENCES addresses(id),
        ADD FOREIGN KEY (to_address_id) REFERENCES addresses(id),
        ADD FOREIGN KEY (transaction_id) REFERENCES transactions(id);
    """
    execute "ALTER TABLE internal_transactions ADD PRIMARY KEY (id);"
    execute "CREATE INDEX internal_transactions_from_address_id_index ON internal_transactions (from_address_id);"
    execute "CREATE INDEX internal_transactions_to_address_id_index ON internal_transactions (to_address_id);"
    execute "CREATE INDEX internal_transactions_transaction_id_index ON internal_transactions (transaction_id);"
    execute "CREATE UNIQUE INDEX internal_transactions_transaction_id_index_index ON internal_transactions (transaction_id, index);"
  end

  def down do
    execute "DROP INDEX internal_transactions_transaction_id_index_index"
  end
end
