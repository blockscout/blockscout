defmodule Explorer.Repo.Optimism.Migrations.AddCelestiaBlobMetadata do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE op_frame_sequence_blob_type AS ENUM ('celestia', 'eip4844')",
      "DROP TYPE op_frame_sequence_blob_type"
    )

    create table(:op_frame_sequence_blobs, primary_key: false) do
      add(:id, :bigint, null: false)
      add(:key, :bytea, null: false, primary_key: true)
      add(:type, :op_frame_sequence_blob_type, null: false, primary_key: true)
      add(:metadata, :map, default: %{}, null: false)
      add(:l1_transaction_hash, :bytea, null: false)
      add(:l1_timestamp, :"timestamp without time zone", null: false)

      add(
        :frame_sequence_id,
        references(:op_frame_sequences, on_delete: :delete_all, on_update: :update_all, type: :bigint),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:op_frame_sequence_blobs, :id))
    create(index(:op_frame_sequence_blobs, :frame_sequence_id))
    create(index(:op_transaction_batches, :frame_sequence_id))
  end
end
