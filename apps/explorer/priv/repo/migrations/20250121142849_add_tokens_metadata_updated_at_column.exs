defmodule Explorer.Repo.Migrations.AddTokensMetadataUpdatedAtColumn do
  use Ecto.Migration

  def up do
    alter table("tokens") do
      add(:metadata_updated_at, :utc_datetime_usec, null: true)
    end
  end

  def down do
    alter table("tokens") do
      remove(:metadata_updated_at)
    end
  end
end
