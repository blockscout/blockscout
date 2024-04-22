# cspell:ignore fkey
defmodule Explorer.Repo.Migrations.DropTokenBalancesTokensForeignKey do
  use Ecto.Migration

  def change do
    drop_if_exists(constraint(:address_token_balances, :address_token_balances_token_contract_address_hash_fkey))
  end
end
