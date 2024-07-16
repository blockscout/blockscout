defmodule Explorer.Repo.Migrations.AddSmartContractLicenseType do
  use Ecto.Migration

  def change do
    alter table("smart_contracts") do
      add(:license_type, :int2, null: false, default: 1)
    end
  end
end
