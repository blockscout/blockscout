defmodule Explorer.Repo.Migrations.AddAddressTokenBalancesAddressHashTokenContractAddressHashBlockNumberIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :address_token_balances,
        ~w(address_hash token_contract_address_hash block_number)a,
        concurrently: true
      )
    )
  end
end
