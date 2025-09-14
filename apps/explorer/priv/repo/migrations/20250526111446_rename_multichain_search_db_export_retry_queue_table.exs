defmodule Explorer.Repo.Migrations.RenameMultichainSearchDbExportRetryQueueTable do
  use Ecto.Migration

  def change do
    rename(table(:multichain_search_db_export_retry_queue), to: table(:multichain_search_db_main_export_queue))

    execute(
      "ALTER TABLE multichain_search_db_main_export_queue RENAME CONSTRAINT multichain_search_db_export_retry_queue_pkey TO multichain_search_db_main_export_queue_pkey"
    )
  end
end
