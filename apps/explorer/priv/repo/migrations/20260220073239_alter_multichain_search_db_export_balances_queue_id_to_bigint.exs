defmodule Explorer.Repo.Migrations.AlterMultichainSearchDbExportBalancesQueueIdToBigint do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Check estimated row count using pg_catalog.pg_class
    result =
      repo().query!("""
      SELECT c.reltuples::bigint
      FROM pg_catalog.pg_class c
      WHERE c.oid = 'multichain_search_db_export_balances_queue'::regclass
      """)

    row_count = result.rows |> List.first() |> List.first() || 0

    # Only alter id column and sequence if row count is less than 10000
    if row_count < 10_000 do
      execute("ALTER TABLE multichain_search_db_export_balances_queue ALTER COLUMN id TYPE bigint")
      execute("ALTER SEQUENCE multichain_search_db_export_balances_queue_id_seq AS bigint")

      # Run VACUUM FULL on the table
      execute("VACUUM FULL public.multichain_search_db_export_balances_queue")
    end
  end

  def down do
    # Note: Reverting bigint to integer could cause data loss if values exceed integer range
    # Only revert if safe to do so
    execute("ALTER SEQUENCE multichain_search_db_export_balances_queue_id_seq AS integer")
    execute("ALTER TABLE multichain_search_db_export_balances_queue ALTER COLUMN id TYPE integer")
  end
end
