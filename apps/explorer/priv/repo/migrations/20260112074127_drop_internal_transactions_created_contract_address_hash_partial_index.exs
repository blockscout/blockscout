defmodule Explorer.Repo.Migrations.DropInternalTransactionsCreatedContractAddressHashPartialIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("DROP INDEX IF EXISTS internal_transactions_created_contract_address_hash_partial_index")
  end

  def down do
    execute(
      "CREATE INDEX IF NOT EXISTS internal_transactions_created_contract_address_hash_partial_index on internal_transactions(created_contract_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE (((type = 'call') AND (index > 0)) OR (type != 'call'));"
    )
  end
end
