defmodule Explorer.Repo.Migrations.UpdateCreditDebitMaterializedView do
  use Ecto.Migration

  def up do
    execute "DROP MATERIALIZED VIEW credits;"
    execute "DROP MATERIALIZED VIEW debits;"

    execute """
    CREATE MATERIALIZED VIEW credits AS
      SELECT addresses.id AS address_id,
        COALESCE(SUM(transactions.value), 0) AS value,
        COUNT(transactions.to_address_id) AS count,
        COALESCE(MIN(transactions.inserted_at), NOW()) AS inserted_at,
        COALESCE(MAX(transactions.inserted_at), NOW()) AS updated_at
      FROM addresses
      INNER JOIN transactions ON transactions.to_address_id = addresses.id
      INNER JOIN receipts ON receipts.transaction_id = transactions.id AND receipts.status = 1
      GROUP BY addresses.id
    ;
    """

    execute """
    CREATE MATERIALIZED VIEW debits AS
      SELECT addresses.id AS address_id,
        COALESCE(SUM(transactions.value), 0) AS value,
        COUNT(transactions.from_address_id) AS count,
        COALESCE(MIN(transactions.inserted_at), NOW()) AS inserted_at,
        COALESCE(MAX(transactions.inserted_at), NOW()) AS updated_at
      FROM addresses
      INNER JOIN transactions ON transactions.from_address_id = addresses.id
      INNER JOIN receipts ON receipts.transaction_id = transactions.id AND receipts.status = 1
      GROUP BY addresses.id
    ;
    """

    create unique_index(:credits, :address_id)
    create index(:credits, :inserted_at)
    create index(:credits, :updated_at)

    create unique_index(:debits, :address_id)
    create index(:debits, :inserted_at)
    create index(:debits, :updated_at)
  end

  def down do
    execute "DROP MATERIALIZED VIEW credits;"
    execute "DROP MATERIALIZED VIEW debits;"
  end
end
