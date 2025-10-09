defmodule Explorer.Repo.Migrations.AddIsBannedToTokenInstances do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:is_banned, :boolean, default: false, null: true)
    end
  end
end
