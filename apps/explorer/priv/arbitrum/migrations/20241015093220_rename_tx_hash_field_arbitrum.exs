defmodule Explorer.Repo.Arbitrum.Migrations.RenameTxHashFieldArbitrum do
  use Ecto.Migration

  def change do
    rename(table(:arbitrum_batch_l2_transactions), :tx_hash, to: :transaction_hash)
  end
end
