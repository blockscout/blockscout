defmodule Explorer.Repo.Migrations.AddSmartContractsCodeMd5 do
  use Ecto.Migration

  def up do
    alter table(:smart_contracts) do
      add(:contract_byte_code_md5, :string, size: 32)
    end

    execute("""
    UPDATE smart_contracts s
    SET contract_byte_code_md5 = md5(a.contract_code::text)
    FROM addresses a
    WHERE a.hash = s.address_hash;
    """)
  end

  def down do
    alter table(:smart_contracts) do
      remove(:contract_byte_code_md5)
    end
  end
end
