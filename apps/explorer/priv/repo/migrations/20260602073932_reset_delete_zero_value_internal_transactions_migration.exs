defmodule Explorer.Repo.Migrations.ResetDeleteZeroValueInternalTransactionsMigration do
  use Ecto.Migration

  def change do
    execute("DELETE FROM migrations_status WHERE migration_name = 'delete_zero_value_internal_transactions'")
  end
end
