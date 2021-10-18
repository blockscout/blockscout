defmodule Explorer.Repo.Migrations.AddTokenBalancesContractAddressHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :address_token_balances,
        ~w(token_contract_address_hash)a,
        concurrently: true
      )
    )
  end
end
