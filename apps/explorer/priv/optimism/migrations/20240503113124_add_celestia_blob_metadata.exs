defmodule Explorer.Repo.Optimism.Migrations.AddCelestiaBlobMetadata do
  use Ecto.Migration

  def change do
    alter table(:op_frame_sequences) do
      add(:celestia_blob_height, :bigint, null: true)
      add(:celestia_blob_namespace, :bytea, null: true)
      add(:celestia_blob_commitment, :bytea, null: true)
    end
  end
end
