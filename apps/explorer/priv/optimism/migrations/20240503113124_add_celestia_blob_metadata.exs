defmodule Explorer.Repo.Optimism.Migrations.AddCelestiaBlobMetadata do
  use Ecto.Migration

  def change do
    alter table(:op_frame_sequences) do
      add(:eip4844_blob_hashes, {:array, :bytea}, null: true)
      add(:celestia_blob_height, :bigint, null: true)
      add(:celestia_blob_namespace, :bytea, null: true)
      add(:celestia_blob_commitment, :bytea, null: true)
    end

    create(index(:op_frame_sequences, [:celestia_blob_commitment, :celestia_blob_height]))
    create(index(:op_transaction_batches, :frame_sequence_id))
  end
end
