defmodule Explorer.Repo.Migrations.AddCsvExportRequests do
  use Ecto.Migration

  def change do
    create table(:csv_export_requests, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:remote_ip_hash, :bytea, null: false)
      add(:file_id, :string)
      add(:status, :string, default: "pending", null: false)
      add(:expires_at, :utc_datetime, null: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      index(:csv_export_requests, [:remote_ip_hash],
        where: "status = 'pending'",
        name: :csv_export_requests_pending_per_ip
      )
    )
  end
end
