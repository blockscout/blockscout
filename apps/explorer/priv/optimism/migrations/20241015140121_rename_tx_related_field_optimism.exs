defmodule Explorer.Repo.Optimism.Migrations.RenameTxRelatedFieldOptimism do
  use Ecto.Migration

  def change do
    rename(table(:transactions), :l1_tx_origin, to: :l1_transaction_origin)
  end
end
