defmodule Explorer.Repo.Migrations.AddStatusToCsvExportRequests do
  use Ecto.Migration

  def change do
    alter table(:csv_export_requests) do
      add(:status, :string, default: "pending", null: false)
    end

    drop(
      index(:csv_export_requests, [:remote_ip_hash],
        where: "file_id IS NULL",
        name: :csv_export_requests_pending_per_ip
      )
    )

    create(
      index(:csv_export_requests, [:remote_ip_hash],
        where: "status = 'pending'",
        name: :csv_export_requests_pending_per_ip
      )
    )
  end
end
