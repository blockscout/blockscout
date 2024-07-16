defmodule Explorer.Repo.Migrations.AddOpWithdrawalsTable do
  use Ecto.Migration

  def change do
    create table(:op_withdrawals, primary_key: false) do
      add(:msg_nonce, :numeric, precision: 100, null: false, primary_key: true)
      add(:withdrawal_hash, :bytea, null: false)
      add(:l2_tx_hash, :bytea, null: false)
      add(:l2_block_number, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
