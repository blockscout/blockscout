defmodule Explorer.Repo.Migrations.AddressNamesAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:address_names) do
      add(:id, :serial, null: false, primary_key: true)
    end
  end
end
