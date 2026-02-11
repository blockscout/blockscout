defmodule Explorer.Repo.Migrations.ResetTokenTransferBlockConsensusMigration do
  use Ecto.Migration

  def change do
    execute("UPDATE migrations_status SET status = 'started' WHERE migration_name = 'token_transfers_block_consensus'")
  end
end
