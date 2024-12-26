defmodule Explorer.Repo.Migrations.DropCurrentTokenBalancesTokensForeignKey do
  use Ecto.Migration

  def change do
    drop_if_exists(
      constraint(:address_current_token_balances, :address_current_token_balances_token_contract_address_hash_fkey)
    )
  end
end
