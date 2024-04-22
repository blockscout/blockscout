defmodule Explorer.Repo.PolygonZkevm.Migrations.AddBridgeTables do
  use Ecto.Migration

  def change do
    create table(:polygon_zkevm_bridge_l1_tokens, primary_key: false) do
      add(:id, :identity, primary_key: true, start_value: 0, increment: 1)
      add(:address, :bytea, null: false)
      add(:decimals, :smallint, null: true, default: nil)
      add(:symbol, :string, size: 16, null: true, default: nil)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:polygon_zkevm_bridge_l1_tokens, :address))

    execute(
      "CREATE TYPE polygon_zkevm_bridge_op_type AS ENUM ('deposit', 'withdrawal')",
      "DROP TYPE polygon_zkevm_bridge_op_type"
    )

    create table(:polygon_zkevm_bridge, primary_key: false) do
      add(:type, :polygon_zkevm_bridge_op_type, null: false, primary_key: true)
      add(:index, :integer, null: false, primary_key: true)
      add(:l1_transaction_hash, :bytea, null: true)
      add(:l2_transaction_hash, :bytea, null: true)

      add(
        :l1_token_id,
        references(:polygon_zkevm_bridge_l1_tokens, on_delete: :restrict, on_update: :update_all, type: :identity),
        null: true
      )

      add(:l1_token_address, :bytea, null: true)
      add(:l2_token_address, :bytea, null: true)
      add(:amount, :numeric, precision: 100, null: false)
      add(:block_number, :bigint, null: true)
      add(:block_timestamp, :"timestamp without time zone", null: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:polygon_zkevm_bridge, :l1_token_address))

    rename(table(:zkevm_lifecycle_l1_transactions), to: table(:polygon_zkevm_lifecycle_l1_transactions))
    rename(table(:zkevm_transaction_batches), to: table(:polygon_zkevm_transaction_batches))
    rename(table(:zkevm_batch_l2_transactions), to: table(:polygon_zkevm_batch_l2_transactions))
  end
end
