defmodule Explorer.Repo.Migrations.RenameTxHashFields do
  use Ecto.Migration

  def change do
    rename(table(:op_output_roots), :l1_tx_hash, to: :l1_transaction_hash)
    rename(table(:op_withdrawals), :l2_tx_hash, to: :l2_transaction_hash)
    rename(table(:op_withdrawal_events), :l1_tx_hash, to: :l1_transaction_hash)
  end
end
