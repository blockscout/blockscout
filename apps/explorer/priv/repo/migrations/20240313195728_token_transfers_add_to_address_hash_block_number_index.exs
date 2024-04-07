defmodule Explorer.Repo.Migrations.TokenTransfersAddToAddressHashBlockNumberIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(index(:token_transfers, [:to_address_hash, :block_number], concurrently: true))
  end
end
