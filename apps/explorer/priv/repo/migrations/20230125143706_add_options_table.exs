defmodule Explorer.Repo.Migrations.AddOptionsTable do
  use Ecto.Migration

  def change do
    create table(:options, primary_key: false) do
      add(:name, :string, null: false, primary_key: true)
      add(:value, :map, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
