defmodule Explorer.Repo.Migrations.VacuumFullMultichainSearchDbExportTokenInfoQueue do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Check estimated row count using pg_catalog.pg_class
    result =
      repo().query!("""
      SELECT c.reltuples::bigint
      FROM pg_catalog.pg_class c
      WHERE c.oid = 'multichain_search_db_export_token_info_queue'::regclass
      """)

    row_count = result.rows |> List.first() |> List.first() || 0

    # Only run VACUUM FULL if row count is less than 10000
    if row_count < 10_000 do
      execute("VACUUM FULL public.multichain_search_db_export_token_info_queue")
    end
  end
end
