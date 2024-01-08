defmodule Explorer.Repo.Migrations.AddSmartContractAuditReportsTable do
  use Ecto.Migration

  def change do
    create table(:smart_contract_audit_reports) do
      add(:smart_contract_address_hash, :bytea, null: false)
      add(:is_approved, :boolean, default: false)

      add(:submitter_name, :string, null: false)
      add(:submitter_email, :string, null: false)
      add(:is_project_owner, :boolean, default: false)

      add(:project_name, :string, null: false)
      add(:project_url, :string, null: false)

      add(:audit_company_name, :string, null: false)
      add(:audit_report_url, :string, null: false)
      add(:audit_publish_date, :date, null: false)

      add(:request_id, :string, null: true)

      add(:comment, :text, null: true)
    end

    create(index(:smart_contract_audit_reports, [:smart_contract_address_hash]))
  end
end
