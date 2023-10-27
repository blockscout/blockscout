defmodule Explorer.Repo.Shibarium.Migrations.AddBridgeTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE shibarium_bridge_op_type AS ENUM ('deposit', 'withdrawal')",
      "DROP TYPE shibarium_bridge_op_type"
    )

    execute(
      "CREATE TYPE shibarium_bridge_token_type AS ENUM ('bone', 'eth', 'other')",
      "DROP TYPE shibarium_bridge_token_type"
    )

    create table(:shibarium_bridge, primary_key: false) do
      add(:user, :bytea, null: false)
      add(:amount_or_id, :numeric, precision: 100, null: true)
      add(:erc1155_ids, {:array, :numeric}, precision: 78, scale: 0, null: true)
      add(:erc1155_amounts, {:array, :decimal}, null: true)
      add(:l1_transaction_hash, :bytea, null: true)
      add(:l2_transaction_hash, :bytea, null: true)
      add(:operation_hash, :bytea, null: false, primary_key: true)
      add(:operation_type, :shibarium_bridge_op_type, null: false, primary_key: true)
      add(:token_type, :shibarium_bridge_token_type, null: false)
      add(:timestamp, :"timestamp without time zone", null: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:shibarium_bridge, :timestamp))
  end
end
