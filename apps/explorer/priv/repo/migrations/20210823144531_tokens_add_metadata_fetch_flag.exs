defmodule Explorer.Repo.Migrations.TokensAddMetadataFetchFlag do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:skip_metadata, :boolean, null: true)
    end
  end
end
