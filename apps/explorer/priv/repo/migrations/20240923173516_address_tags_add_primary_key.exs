defmodule Explorer.Repo.Migrations.AddressTagsAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:address_tags) do
      modify(:label, :string, null: false, primary_key: true)
    end
  end
end
