defmodule Explorer.Repo.Migrations.AddNFTMediaUrls do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:thumbnails, :jsonb, null: true)
      add(:media_type, :string, null: true)
      add(:cdn_upload_error, :string, null: true)
    end
  end
end
