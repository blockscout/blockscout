defmodule Explorer.Repo.Migrations.RenameL2TxHashField do
  use Ecto.Migration

  def change do
    rename(table(:op_withdrawals), :l2_tx_hash, to: :l2_transaction_hash)
  end
end
