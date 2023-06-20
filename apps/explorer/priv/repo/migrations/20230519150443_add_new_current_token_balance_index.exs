defmodule Explorer.Repo.Migrations.AddNewCurrentTokenBalanceIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(
        :address_current_token_balances,
        [
          :address_hash,
          :token_type
        ],
        where: "value > 0",
        concurrently: true
      )
    )
  end
end
