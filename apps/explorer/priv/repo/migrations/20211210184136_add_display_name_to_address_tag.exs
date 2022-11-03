defmodule Explorer.Repo.Migrations.AddDisplayNameToAddressTag do
  use Ecto.Migration

  def up do
    alter table(:address_tags) do
      add(:display_name, :string, null: true)
    end
  end

  def down do
    alter table(:address_tags) do
      remove(:display_name)
    end
  end
end
