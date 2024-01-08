defmodule Explorer.Repo.Migrations.CreateMigrationsStatus do
  use Ecto.Migration

  def change do
    create table(:migrations_status, primary_key: false) do
      add(:migration_name, :string, primary_key: true)
      add(:status, :string)

      timestamps()
    end
  end
end
