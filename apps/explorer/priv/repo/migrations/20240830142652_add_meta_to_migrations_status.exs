defmodule Explorer.Repo.Migrations.AddMetaToMigrationsStatus do
  use Ecto.Migration

  def change do
    alter table(:migrations_status) do
      add(:meta, :map)
    end
  end
end
