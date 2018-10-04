defmodule Explorer.Repo.Migrations.AlterSmartContractsTableRemoveForeignKey do
  use Ecto.Migration

  def up do
    alter table("smart_contracts") do
      modify(:address_hash, :bytea, null: false)
    end

    drop(constraint(:smart_contracts, "smart_contracts_address_hash_fkey"))
  end

  def down do
    alter table("smart_contracts") do
      modify(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
    end
  end
end
