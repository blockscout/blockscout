defmodule Explorer.Repo.Arbitrum.Migrations.AddStylusFields do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:package_name, :string, null: true)
      add(:github_repository_metadata, :jsonb, null: true)
    end
  end
end
