defmodule Explorer.Repo.ZkSync.Migrations.RenameTxCountFieldsZksync do
  use Ecto.Migration

  def change do
    rename(table(:zksync_transaction_batches), :l1_tx_count, to: :l1_transaction_count)
    rename(table(:zksync_transaction_batches), :l2_tx_count, to: :l2_transaction_count)
  end
end
