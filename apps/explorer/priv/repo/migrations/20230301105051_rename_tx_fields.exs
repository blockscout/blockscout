defmodule Explorer.Repo.Migrations.RenameTxFields do
  use Ecto.Migration

  def change do
    rename(table(:op_transaction_batches), :l1_tx_hashes, to: :l1_transaction_hashes)
    rename(table(:op_transaction_batches), :l1_tx_timestamp, to: :l1_timestamp)
    rename(table(:op_output_roots), :l1_tx_hash, to: :l1_transaction_hash)
    rename(table(:op_withdrawals), :l2_tx_hash, to: :l2_transaction_hash)
    rename(table(:op_withdrawal_events), :l1_tx_hash, to: :l1_transaction_hash)
  end
end
