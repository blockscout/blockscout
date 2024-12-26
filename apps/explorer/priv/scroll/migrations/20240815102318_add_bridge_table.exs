defmodule Explorer.Repo.Scroll.Migrations.AddBridgeTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE scroll_bridge_op_type AS ENUM ('deposit', 'withdrawal')",
      "DROP TYPE scroll_bridge_op_type"
    )

    create table(:scroll_bridge, primary_key: false) do
      add(:type, :scroll_bridge_op_type, null: false, primary_key: true)
      add(:index, :integer, null: true)
      add(:l1_transaction_hash, :bytea, null: true)
      add(:l2_transaction_hash, :bytea, null: true)
      add(:amount, :numeric, precision: 100, null: true)
      add(:block_number, :bigint, null: true)
      add(:block_timestamp, :"timestamp without time zone", null: true)
      add(:message_hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:scroll_bridge, [:type, :index]))
  end
end
