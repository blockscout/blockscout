defmodule Explorer.Repo.Migrations.ModifyAddressTokenBalancesIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        name: :fetched_token_balances,
        where: "token_id IS NULL"
      )
    )

    drop_if_exists(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash token_id block_number)a,
        name: :fetched_token_balances_with_token_id,
        where: "token_id IS NOT NULL"
      )
    )

    create_if_not_exists(
      unique_index(
        :address_token_balances,
        [:address_hash, :token_contract_address_hash, "COALESCE(token_id, 0)", :block_number],
        name: :fetched_token_balances
      )
    )

    drop_if_exists(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        name: :unfetched_token_balances,
        where: "value_fetched_at IS NULL and token_id IS NULL"
      )
    )

    drop_if_exists(
      unique_index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash token_id block_number)a,
        name: :unfetched_token_balances_with_token_id,
        where: "value_fetched_at IS NULL and token_id IS NOT NULL"
      )
    )

    create_if_not_exists(
      unique_index(
        :address_token_balances,
        [:address_hash, :token_contract_address_hash, "COALESCE(token_id, 0)", :block_number],
        name: :unfetched_token_balances,
        where: "value_fetched_at IS NULL"
      )
    )
  end
end
