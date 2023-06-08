defmodule Explorer.Repo.Migrations.AddOpOutputRootsTable do
  use Ecto.Migration

  def change do
    create table(:op_output_roots, primary_key: false) do
      add(:l2_output_index, :bigint, null: false, primary_key: true)
      add(:l2_block_number, :bigint, null: false)
      add(:l1_tx_hash, :bytea, null: false)
      add(:l1_timestamp, :"timestamp without time zone", null: false)
      add(:l1_block_number, :bigint, null: false)
      add(:output_root, :bytea, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
