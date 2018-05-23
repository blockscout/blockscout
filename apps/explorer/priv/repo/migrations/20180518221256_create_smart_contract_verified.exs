defmodule Explorer.Repo.Migrations.CreateSmartContractVerified do
  use Ecto.Migration

  def change do
    create table(:smart_contracts) do
      add(:name, :string, null: false)
      add(:compiler_version, :string, null: false)
      add(:optimization, :boolean, null: false)
      add(:contract_source_code, :text, null: false)
      add(:abi, :jsonb, null: false)

      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      timestamps()
    end

    create(unique_index(:smart_contracts, :address_hash))
  end
end
