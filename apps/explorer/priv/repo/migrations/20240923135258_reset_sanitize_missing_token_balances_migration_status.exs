defmodule Explorer.Repo.Migrations.ResetSanitizeMissingTokenBalancesMigrationStatus do
  use Ecto.Migration

  def change do
    execute("DELETE FROM migrations_status WHERE migration_name = 'sanitize_missing_token_balances'")
  end
end
