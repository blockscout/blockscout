defmodule Explorer.Repo.Migrations.AddMetadataURL do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:metadata_url, :string, null: true, size: 2048)
      add(:skip_metadata_url, :boolean, null: true)
    end
  end
end
