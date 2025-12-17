defmodule Explorer.Repo.Beacon.Migrations.DepositsRemoveForeignKeys do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists(constraint(:beacon_deposits, :beacon_deposits_block_hash_fkey))
    drop_if_exists(constraint(:beacon_deposits, :beacon_deposits_from_address_hash_fkey))
    drop_if_exists(constraint(:beacon_deposits, :beacon_deposits_transaction_hash_fkey))
  end
end
