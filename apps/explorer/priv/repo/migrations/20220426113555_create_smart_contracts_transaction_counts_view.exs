defmodule Explorer.Repo.Migrations.CreateSmartContractsTransactionCountsView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE MATERIALIZED VIEW IF NOT EXISTS smart_contract_transaction_counts AS
    WITH last_block_number AS (
      SELECT
        MAX(number) - 17280 * 90 AS number
      FROM blocks
    )
    SELECT
      to_address_hash AS address_hash,
      COUNT(*) as transaction_count
    FROM transactions
    WHERE
      to_address_hash IN (SELECT address_hash FROM smart_contracts)
      AND block_number > (SELECT number FROM last_block_number)
    GROUP BY to_address_hash;
    """)
  end

  def down do
    execute("""
    DROP MATERIALIZED VIEW IF EXISTS smart_contract_transaction_counts;
    """)
  end
end
