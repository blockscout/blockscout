defmodule Explorer.Repo.Migrations.AddExpiresAt do
  use Ecto.Migration

  def change do
    alter table(:csv_export_requests) do
      add(:expires_at, :utc_datetime, null: true)
    end
  end
end
