defmodule Explorer.Repo.PolygonZkevm.Migrations.AddBridgeTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE zkevm_bridge_op_type AS ENUM ('deposit', 'withdrawal')",
      "DROP TYPE zkevm_bridge_op_type"
    )

    create table(:zkevm_bridge, primary_key: false) do
      add(:type, :zkevm_bridge_op_type, null: false, primary_key: true)
      add(:index, :integer, null: false, primary_key: true)
      add(:l1_transaction_hash, :bytea, null: true, default: nil)
      add(:l2_transaction_hash, :bytea, null: true, default: nil)
      add(:l1_token_address, :bytea, null: true, default: nil)
      add(:l1_token_decimals, :smallint, null: true, default: nil)
      add(:l1_token_symbol, :string, size: 16, null: true, default: nil)
      add(:amount, :numeric, precision: 100, null: false)
      add(:block_number, :bigint, null: true, default: nil)
      add(:block_timestamp, :"timestamp without time zone", null: true, default: nil)
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
