# cspell:ignore fkey
defmodule Explorer.Repo.Migrations.DropRestAddressForeignKeys do
  use Ecto.Migration

  def change do
    drop_if_exists(constraint(:address_coin_balances_daily, :address_coin_balances_daily_address_hash_fkey))
    drop_if_exists(constraint(:address_to_tags, :address_to_tags_address_hash_fkey))
    drop_if_exists(constraint(:block_rewards, :block_rewards_address_hash_fkey))
    drop_if_exists(constraint(:decompiled_smart_contracts, :decompiled_smart_contracts_address_hash_fkey))
    drop_if_exists(constraint(:smart_contracts, :smart_contracts_address_hash_fkey))
    drop_if_exists(constraint(:withdrawals, :withdrawals_address_hash_fkey))
    drop_if_exists(constraint(:blocks, :blocks_miner_hash_fkey))
  end
end
