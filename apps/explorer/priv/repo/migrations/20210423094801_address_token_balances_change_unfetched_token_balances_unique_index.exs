defmodule Explorer.Repo.Migrations.AddressTokenBalancesChangeUnfetchedTokenBalancesUniqueIndex do
  use Ecto.Migration

  def change do
    drop(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        name: :unfetched_token_balances,
        where: "value_fetched_at IS NULL"
      )
    )

    create(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        name: :unfetched_token_balances,
        where: "value_fetched_at IS NULL and token_id IS NULL"
      )
    )

    create(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash token_id block_number)a,
        name: :unfetched_token_balances_with_token_id,
        where: "value_fetched_at IS NULL and token_id IS NOT NULL"
      )
    )
  end
end
