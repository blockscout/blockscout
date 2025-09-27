defmodule Explorer.Repo.Optimism.Migrations.AddAltDABlobs do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE op_frame_sequence_blob_type ADD VALUE 'alt_da'")
  end
end
