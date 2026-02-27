defmodule Explorer.Repo.Migrations.ResetTokenTransferBlockConsensusMigration do
  use Ecto.Migration

  def change do
    execute("DELETE FROM migrations_status WHERE migration_name = 'token_transfers_block_consensus'")
  end
end
