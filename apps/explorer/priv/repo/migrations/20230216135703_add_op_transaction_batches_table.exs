defmodule Explorer.Repo.Migrations.AddOpTransactionBatchesTable do
  use Ecto.Migration

  def change do
    create table(:op_transaction_batches, primary_key: false) do
      add(:l2_block_number, :bigint, null: false, primary_key: true)
      add(:tx_count, :integer, null: false)
      add(:epoch_number, :bigint, null: false)
      add(:l1_tx_hashes, {:array, :bytea}, null: false)
      add(:l1_tx_timestamp, :"timestamp without time zone", null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
