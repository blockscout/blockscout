defmodule Explorer.Repo.Migrations.SmartContractsContractCodeMd5 do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:contract_code_md5, :string, null: true)
    end

    execute("""
      UPDATE smart_contracts
      SET contract_code_md5 = md5(a.contract_code)
      FROM addresses a
      WHERE smart_contracts.address_hash = a.hash;
    """)

    alter table(:smart_contracts) do
      modify(:contract_code_md5, :string, null: false)
    end

    drop_if_exists(index(:addresses, ["md5(contract_code::text)"], name: "addresses_contract_code_index"))
    create(index(:smart_contracts, :contract_code_md5))
  end
end
