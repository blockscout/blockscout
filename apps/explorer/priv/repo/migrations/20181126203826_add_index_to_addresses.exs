defmodule Explorer.Repo.Migrations.AddIndexToAddresses do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX addresses_fetched_coin_balance_hash_index ON addresses (fetched_coin_balance DESC, hash ASC) WHERE fetched_coin_balance > 0"
    )
  end

  def down do
    execute("DROP INDEX addresses_fetched_coin_balance_hash_index")
  end
end
