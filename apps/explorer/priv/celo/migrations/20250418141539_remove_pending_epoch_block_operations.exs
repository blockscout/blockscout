defmodule Explorer.Repo.Celo.Migrations.RemovePendingEpochBlockOperations do
  use Ecto.Migration

  def change do
    drop(table(:celo_pending_epoch_block_operations))
  end
end
