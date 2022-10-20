defmodule Explorer.Repo.Migrations.SmartContractsRemoveMd5 do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE smart_contracts DROP COLUMN IF EXISTS contract_byte_code_md5;")
  end
end
