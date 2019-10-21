defmodule Explorer.Repo.Migrations.AddIndexOnAddressHashBlockNumberAndTokenContractAddressHashForCurrentTokenBalance do
  use Ecto.Migration

  def change do
    create(index(:address_current_token_balances, [:address_hash, :block_number, :token_contract_address_hash]))
  end
end
