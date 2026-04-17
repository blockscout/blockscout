defmodule Explorer.Repo.Migrations.AlterContractVerificationStatusTable do
  use Ecto.Migration

  def up do
    rename(table(:contract_verification_status), to: table(:smart_contract_verification_statuses))
    execute("ALTER INDEX contract_verification_status_pkey RENAME TO smart_contract_verification_statuses_pkey")
    rename(table(:smart_contract_verification_statuses), :address_hash, to: :contract_address_hash)
  end

  def down do
    rename(table(:smart_contract_verification_statuses), to: table(:contract_verification_status))

    execute("ALTER INDEX smart_contract_verification_statuses_pkey RENAME TO contract_verification_status_pkey")

    rename(table(:contract_verification_status), :contract_address_hash, to: :address_hash)
  end
end
