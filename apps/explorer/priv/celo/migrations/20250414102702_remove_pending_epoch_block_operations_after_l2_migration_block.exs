defmodule Explorer.Repo.Celo.Migrations.RemovePendingEpochBlockOperationsAfterL2MigrationBlock do
  use Ecto.Migration

  def change do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    execute("""
    DELETE FROM celo_pending_epoch_block_operations WHERE block_hash IN
    (SELECT hash FROM blocks WHERE number >= #{l2_migration_block_number})
    """)
  end
end
