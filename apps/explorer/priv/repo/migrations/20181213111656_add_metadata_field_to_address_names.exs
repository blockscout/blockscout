defmodule Explorer.Repo.Migrations.AddMetadataFieldToAddressNames do
  use Ecto.Migration

  def change do
    alter table(:address_names) do
      add(:metadata, :map)
    end
  end
end
