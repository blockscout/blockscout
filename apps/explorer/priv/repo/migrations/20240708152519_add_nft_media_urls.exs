defmodule Explorer.Repo.Migrations.AddNFTMediaUrls do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:media_urls, :jsonb, null: true)
      add(:media_type, :string, null: true)
    end
  end
end
