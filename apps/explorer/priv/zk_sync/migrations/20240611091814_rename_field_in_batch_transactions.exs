defmodule Explorer.Repo.ZkSync.Migrations.RenameFieldInBatchTransactions do
  use Ecto.Migration

  def change do
    rename(table(:zksync_batch_l2_transactions), :hash, to: :tx_hash)
  end
end
