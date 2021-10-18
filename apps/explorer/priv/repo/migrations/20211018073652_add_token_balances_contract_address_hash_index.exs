defmodule Explorer.Repo.Migrations.AddTokenBalancesContractAddressHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

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
