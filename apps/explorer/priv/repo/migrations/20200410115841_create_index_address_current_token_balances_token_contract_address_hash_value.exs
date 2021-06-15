defmodule Explorer.Repo.Migrations.CreateIndexAddressCurrentTokenBalancesTokenContractAddressHashValue do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:address_current_token_balances, [:token_contract_address_hash, :value]))
  end
end
