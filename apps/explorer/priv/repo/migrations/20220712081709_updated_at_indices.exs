defmodule Explorer.Repo.Migrations.UpdatedAtIndices do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  @tables ~w(
    blocks
    celo_wallets
    address_current_token_balances
    address_token_balances
    addresses
    token_transfers
  )a

  def change do
    for table <- @tables, do: create_if_not_exists(index(table, [:updated_at], concurrently: true))
  end
end
