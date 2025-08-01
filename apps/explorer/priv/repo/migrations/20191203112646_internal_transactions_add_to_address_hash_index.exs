defmodule Explorer.Repo.Migrations.InternalTransactionsAddToAddressHashIndex do
  use Ecto.Migration

  def change do
    execute(
      "CREATE INDEX IF NOT EXISTS internal_transactions_from_address_hash_partial_index on internal_transactions(from_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE (((type = 'call') AND (index > 0)) OR (type != 'call'));"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS internal_transactions_to_address_hash_partial_index on internal_transactions(to_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE (((type = 'call') AND (index > 0)) OR (type != 'call'));"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS internal_transactions_created_contract_address_hash_partial_index on internal_transactions(created_contract_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE (((type = 'call') AND (index > 0)) OR (type != 'call'));"
    )

    drop_if_exists(
      index(
        :internal_transactions,
        [:to_address_hash, :from_address_hash, :created_contract_address_hash, :type, :index],
        name: "internal_transactions_to_address_hash_from_address_hash_created"
      )
    )
  end
end
