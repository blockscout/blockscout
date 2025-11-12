defmodule Explorer.Repo.Migrations.ResetSanitizeDuplicatedLogsMigration do
  use Ecto.Migration

  def change do
    execute("DELETE FROM migrations_status WHERE migration_name = 'sanitize_duplicated_log_index_logs'")
  end
end
