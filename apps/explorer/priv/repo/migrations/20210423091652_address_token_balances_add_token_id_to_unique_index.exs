defmodule Explorer.Repo.Migrations.AddressTokenBalancesAddTokenIdToUniqueIndex do
  use Ecto.Migration

  def change do
    drop(unique_index(:address_token_balances, ~w(address_hash token_contract_address_hash block_number)a))

    create(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash token_id block_number)a,
        name: :fetched_token_balances_with_token_id,
        where: "token_id IS NOT NULL"
      )
    )

    create(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        name: :fetched_token_balances,
        where: "token_id IS NULL"
      )
    )
  end
end
