defmodule Explorer.Repo.Migrations.AddOpFrameSequencesTable do
  use Ecto.Migration

  def change do
    create table(:op_frame_sequences, primary_key: true) do
      add(:l1_transaction_hashes, {:array, :bytea}, null: false)
      add(:l1_timestamp, :"timestamp without time zone", null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    alter table(:op_transaction_batches) do
      remove(:l1_transaction_hashes)
      remove(:l1_timestamp)

      add(
        :frame_sequence_id,
        references(:op_frame_sequences, on_delete: :restrict, on_update: :update_all, type: :bigint),
        null: false,
        after: :epoch_number
      )
    end
  end
end
