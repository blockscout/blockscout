defmodule Explorer.Repo.Migrations.UpdateCreditDebitMaterializedView do
  use Ecto.Migration

  def down do
    execute("DROP MATERIALIZED VIEW IF EXISTS credits;")
    execute("DROP MATERIALIZED VIEW IF EXISTS debits;")
  end

  def up do
    execute("DROP MATERIALIZED VIEW IF EXISTS credits;")
    execute("DROP MATERIALIZED VIEW IF EXISTS debits;")

    execute("""
    CREATE MATERIALIZED VIEW credits AS
      SELECT addresses.hash AS address_hash,
        COALESCE(SUM(transactions.value), 0) AS value,
        COUNT(transactions.to_address_hash) AS count,
        COALESCE(MIN(transactions.inserted_at), NOW()) AS inserted_at,
        COALESCE(MAX(transactions.inserted_at), NOW()) AS updated_at
      FROM addresses
      INNER JOIN transactions ON transactions.to_address_hash = addresses.hash
      INNER JOIN receipts ON receipts.transaction_hash = transactions.hash AND receipts.status = 1
      GROUP BY addresses.hash
    ;
    """)

    execute("""
    CREATE MATERIALIZED VIEW debits AS
      SELECT addresses.hash AS address_hash,
        COALESCE(SUM(transactions.value), 0) AS value,
        COUNT(transactions.from_address_hash) AS count,
        COALESCE(MIN(transactions.inserted_at), NOW()) AS inserted_at,
        COALESCE(MAX(transactions.inserted_at), NOW()) AS updated_at
      FROM addresses
      INNER JOIN transactions ON transactions.from_address_hash = addresses.hash
      INNER JOIN receipts ON receipts.transaction_hash = transactions.hash AND receipts.status = 1
      GROUP BY addresses.hash
    ;
    """)

    create(unique_index(:credits, :address_hash))
    create(index(:credits, :inserted_at))
    create(index(:credits, :updated_at))

    create(unique_index(:debits, :address_hash))
    create(index(:debits, :inserted_at))
    create(index(:debits, :updated_at))
  end
end
