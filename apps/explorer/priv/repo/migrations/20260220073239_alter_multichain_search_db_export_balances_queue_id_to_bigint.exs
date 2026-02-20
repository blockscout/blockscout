defmodule Explorer.Repo.Migrations.AlterMultichainSearchDbExportBalancesQueueIdToBigint do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  @table_name "multichain_search_db_export_balances_queue"

  def up do
    # Check estimated row count using pg_catalog.pg_class
    result =
      repo().query!("""
      SELECT c.reltuples::bigint
      FROM pg_catalog.pg_class c
      WHERE c.oid = '#{@table_name}'::regclass
      """)

    row_count = result.rows |> List.first() |> List.first() || 0

    # Only alter id column and sequence if row count is less than 10000
    if row_count < 10_000 do
      execute("ALTER TABLE #{@table_name} ALTER COLUMN id TYPE bigint")
      execute("ALTER SEQUENCE #{@table_name}_id_seq AS bigint")

      # Run VACUUM FULL on the table
      execute("VACUUM FULL #{@table_name}")
    end
  end

  def down do
    # Note: Reverting bigint to integer could cause data loss if values exceed integer range
    # Only revert if safe to do so
    execute("ALTER SEQUENCE #{@table_name}_id_seq AS integer")
    execute("ALTER TABLE #{@table_name} ALTER COLUMN id TYPE integer")
  end
end
