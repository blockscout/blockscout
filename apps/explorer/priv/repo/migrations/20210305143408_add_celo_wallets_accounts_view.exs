defmodule Explorer.Repo.Migrations.AddCeloWalletsAccountsView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE MATERIALIZED VIEW IF NOT EXISTS celo_wallet_accounts AS
      SELECT DISTINCT ON (wallet_address_hash) wallet_address_hash, account_address_hash, block_number
      FROM celo_wallets ORDER BY wallet_address_hash, block_number DESC
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS celo_wallet_accounts_wallet_address_hash ON celo_wallet_accounts(wallet_address_hash ASC, block_number DESC)
    """)
  end

  def down do
    execute("""
    DROP MATERIALIZED VIEW IF EXISTS celo_wallet_accounts
    """)
  end
end
