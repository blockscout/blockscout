defmodule Explorer.Repo.Migrations.AddressCurrentTokenBalancesAddTokenIdToUniqueIndex do
  use Ecto.Migration

  def change do
    drop(unique_index(:address_current_token_balances, ~w(address_hash token_contract_address_hash)a))
    create(unique_index(:address_current_token_balances, ~w(address_hash token_contract_address_hash token_id)a))
  end
end
