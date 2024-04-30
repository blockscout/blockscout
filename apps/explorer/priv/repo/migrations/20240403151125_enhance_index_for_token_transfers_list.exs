defmodule Explorer.Repo.Migrations.EnhanceIndexForTokenTransfersList do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:token_transfers, ["token_contract_address_hash, block_number DESC, log_index DESC"], concurrently: true)
    )
  end
end
