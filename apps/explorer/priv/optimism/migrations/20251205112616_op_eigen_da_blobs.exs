defmodule Explorer.Repo.Optimism.Migrations.OPEigenDABlobs do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE op_frame_sequence_blob_type ADD VALUE IF NOT EXISTS 'eigenda'")
  end
end
