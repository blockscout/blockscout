defmodule Explorer.Repo.Migrations.DropOutdatedIndexForTokenTransfersList do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists(index(:token_transfers, [:token_contract_address_hash, :block_number], concurrently: true))
  end
end
