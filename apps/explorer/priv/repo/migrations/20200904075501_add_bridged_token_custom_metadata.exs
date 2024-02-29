defmodule Explorer.Repo.Migrations.AddBridgedTokenCustomMetadata do
  use Ecto.Migration

  def change do
    alter table(:bridged_tokens) do
      add(:custom_metadata, :string, null: true)
    end
  end
end
