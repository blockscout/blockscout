defmodule Explorer.Repo.Migrations.AddCsvExportRequests do
  use Ecto.Migration

  def change do
    create table(:csv_export_requests, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:remote_ip_hash, :bytea, null: false)
      add(:file_id, :string)

      timestamps(type: :utc_datetime_usec)
    end

    # Optimizes the pending-count query:
    # WHERE remote_ip_hash = ? AND file_id IS NULL
    create(
      index(:csv_export_requests, [:remote_ip_hash],
        where: "file_id IS NULL",
        name: :csv_export_requests_pending_per_ip
      )
    )
  end
end
