defmodule Explorer.Repo.Migrations.CreateL1ToL2 do
  use Ecto.Migration

  def change do
    create table(:l1_to_l2, primary_key: false) do
      add(:hash, :bytea)
      add(:l2_hash, :bytea, null: false, primary_key: true)
      add(:block, :bigint, null: false)
      add(:msg_nonce, :bigint, null: false)
      add(:from_address, :bytea, null: false)
      add(:txn_batch_index, :bigint, null: false)
      add(:state_batch_index, :bigint, null: false)
      add(:timestamp, :utc_datetime_usec, null: false)
      add(:status, :string, null: false)
      add(:gas_limit, :numeric, precision: 100, null: false)
      add(:gas_used, :numeric, precision: 100, null: false)
      add(:gas_price, :numeric, precision: 100, null: false)
      add(:fee_scalar, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
