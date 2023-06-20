defmodule Explorer.Repo.Migrations.CreatePolygonSupernetWithdrawalTables do
  use Ecto.Migration

  def change do
    create table(:polygon_supernet_withdrawals, primary_key: false) do
      add(:msg_id, :bigint, null: false, primary_key: true)
      add(:from, :bytea, null: true)
      add(:to, :bytea, null: true)
      add(:l2_transaction_hash, :bytea, null: false)
      add(:l2_block_number, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:polygon_supernet_withdrawal_exits, primary_key: false) do
      add(:msg_id, :bigint, null: false, primary_key: true)
      add(:l1_transaction_hash, :bytea, null: false)
      add(:l1_block_number, :bigint, null: false)
      add(:success, :boolean, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:polygon_supernet_withdrawals, :l2_transaction_hash))
    create(index(:polygon_supernet_withdrawals, :l2_block_number))
    create(index(:polygon_supernet_withdrawal_exits, :l1_block_number))
  end
end
