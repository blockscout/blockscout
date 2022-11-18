defmodule Explorer.Repo.Migrations.ModifyAddressCurrentTokenBalancesIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(
        :address_current_token_balances,
        ~w(address_hash token_contract_address_hash)a,
        name: :fetched_current_token_balances,
        where: "token_id IS NULL"
      )
    )

    drop_if_exists(
      unique_index(
        :address_current_token_balances,
        ~w(address_hash token_contract_address_hash token_id)a,
        name: :fetched_current_token_balances_with_token_id,
        where: "token_id IS NOT NULL"
      )
    )

    create_if_not_exists(
      unique_index(
        :address_current_token_balances,
        [:address_hash, :token_contract_address_hash, "COALESCE(token_id, 0)"],
        name: :fetched_current_token_balances
      )
    )
  end
end
