defmodule Explorer.Repo.Migrations.ModifyAddressCurrentTokenBalancesIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(
        :address_current_token_balances,
        ~w(address_hash token_contract_address_hash token_id)a,
        name: :fetched_current_token_balances
      )
    )

    create_if_not_exists(
      unique_index(
        :address_current_token_balances,
        [:address_hash, :token_contract_address_hash, "COALESCE(token_id, -1)"],
        name: :fetched_current_token_balances
      )
    )
  end
end
