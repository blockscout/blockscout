defmodule Explorer.Repo.Migrations.IndexCurrentTokenHolders do
  use Ecto.Migration

  def change do
    create(
      index(:address_current_token_balances, [:token_contract_address_hash],
        where: "address_hash != '\\x0000000000000000000000000000000000000000' AND value > 0"
      )
    )
  end
end
