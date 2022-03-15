defmodule Explorer.Repo.Migrations.PositiveAddressCurrentTokenBalances do
  use Ecto.Migration

  def change do
    create(
      index(:address_current_token_balances, [:address_hash, :token_contract_address_hash],
        where: ~s["value" > 0],
        name: :positive_address_current_token_balances
      )
    )
  end
end
