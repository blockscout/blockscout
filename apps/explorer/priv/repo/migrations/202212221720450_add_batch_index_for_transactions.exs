defmodule Explorer.Repo.Migrations.AddBatchIndexForTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:eigen_txn_batch_index, :bigint, null: true)
      add(:eigen_submission_tx_hash, :bytea, null: true)
      add(:l1_state_batch_index, :bigint, null: true)
      add(:l1_state_root_submission_tx_hash, :bytea, null: true)
      add(:l1_origin_tx_hash, :bytea, null: true)
      add(:l1_gas_price, :numeric, precision: 100, null: true)
      add(:l1_gas_used, :numeric, precision: 100, null: true)
      add(:l1_fee, :numeric, precision: 100, null: true)
      add(:l1_fee_scalar, :numeric, precision: 10, scale: 2, null: true)
    end
  end
end
