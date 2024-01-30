defmodule Explorer.Repo.Migrations.AddProxyVerificationStatus do
  use Ecto.Migration

  def change do
    create table("proxy_smart_contract_verification_statuses", primary_key: false) do
      add(:uid, :string, size: 64, primary_key: true)
      add(:status, :int2, null: false)

      add(
        :contract_address_hash,
        references(:smart_contracts, column: :address_hash, on_delete: :delete_all, type: :bytea)
      )

      timestamps()
    end
  end
end
