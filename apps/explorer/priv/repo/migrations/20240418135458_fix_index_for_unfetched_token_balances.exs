defmodule Explorer.Repo.Migrations.FixIndexForUnfetchedTokenBalances do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:address_token_balances, ["id"],
        name: "unfetched_address_token_balances_v2_index",
        where:
          "((address_hash != '\\x0000000000000000000000000000000000000000' AND token_type = 'ERC-721') OR token_type = 'ERC-20' OR token_type = 'ERC-1155' OR token_type = 'ERC-404') AND (value_fetched_at IS NULL OR value IS NULL)",
        concurrently: true
      )
    )
  end
end
