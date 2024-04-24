defmodule Explorer.Repo.Migrations.DropOutdatedIndexForUnfetchedTokenBalances do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists(
      index(
        :address_token_balances,
        ~w(id)a,
        name: :unfetched_address_token_balances_index,
        where:
          "((address_hash != '\\x0000000000000000000000000000000000000000' AND token_type = 'ERC-721') OR token_type = 'ERC-20' OR token_type = 'ERC-1155') AND (value_fetched_at IS NULL OR value IS NULL)",
        concurrently: true
      )
    )
  end
end
