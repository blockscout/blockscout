defmodule Explorer.Repo.ZkSync.Migrations.RenameTxHashFieldArbitrum do
  use Ecto.Migration

  def change do
    rename(table(:zksync_batch_l2_transactions), :tx_hash, to: :transaction_hash)
  end
end
