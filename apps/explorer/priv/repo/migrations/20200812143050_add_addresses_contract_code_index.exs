defmodule Explorer.Repo.Migrations.AddAddressesContractCodeIndex do
  use Ecto.Migration

  def change do
    execute("CREATE INDEX addresses_contract_code_index ON addresses (md5(contract_code::text));")
  end
end
