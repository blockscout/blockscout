defmodule Explorer.Repo.Migrations.AddressTokenBalancesAddTokenIdToUniqueIndex do
  use Ecto.Migration

  def change do
    drop(unique_index(:address_token_balances, ~w(address_hash token_contract_address_hash block_number)a))
    create(unique_index(:address_token_balances, ~w(address_hash token_contract_address_hash token_id block_number)a))
  end
end
