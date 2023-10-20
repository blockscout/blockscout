defmodule Explorer.Repo.PolygonEdge.Migrations.CreatePolygonEdgeDepositTables do
  use Ecto.Migration

  def change do
    create table(:polygon_edge_deposits, primary_key: false) do
      add(:msg_id, :bigint, null: false, primary_key: true)
      add(:from, :bytea, null: true)
      add(:to, :bytea, null: true)
      add(:l1_transaction_hash, :bytea, null: false)
      add(:l1_block_number, :bigint, null: false)
      add(:l1_timestamp, :"timestamp without time zone", null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:polygon_edge_deposit_executes, primary_key: false) do
      add(:msg_id, :bigint, null: false, primary_key: true)
      add(:l2_transaction_hash, :bytea, null: false)
      add(:l2_block_number, :bigint, null: false)
      add(:success, :boolean, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:polygon_edge_deposit_executes, :l2_transaction_hash))
    create(index(:polygon_edge_deposits, :l1_block_number))
    create(index(:polygon_edge_deposit_executes, :l2_block_number))
  end
end
