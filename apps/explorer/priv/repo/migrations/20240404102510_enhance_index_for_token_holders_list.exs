defmodule Explorer.Repo.Migrations.EnhanceIndexForTokenHoldersList do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:address_current_token_balances, ["token_contract_address_hash, value DESC, address_hash DESC"],
        where: "address_hash != '\\x0000000000000000000000000000000000000000' AND value > 0",
        concurrently: true
      )
    )
  end
end
