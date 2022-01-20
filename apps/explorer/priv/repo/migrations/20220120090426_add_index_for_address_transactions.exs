defmodule Explorer.Repo.Migrations.AddIndexForAddressTransactions do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        [:from_address_hash, "inserted_at DESC", "hash DESC"],
        where: "block_number IS NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "from_address_hash_pending_transactions_index"
      )
    )

    create(
      index(
        :transactions,
        [:to_address_hash, "inserted_at DESC", "hash DESC"],
        where: "block_number IS NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "to_address_hash_pending_transactions_index"
      )
    )

    create(
      index(
        :transactions,
        [:created_contract_address_hash, "inserted_at DESC", "hash DESC"],
        where: "block_number IS NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "created_contract_address_hash_pending_transactions_index"
      )
    )

    create(
      index(
        :transactions,
        [:from_address_hash, "block_number DESC", "index DESC"],
        where: "block_number IS NOT NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "from_address_hash_confirmed_transactions_index"
      )
    )

    create(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC", "index DESC"],
        where: "block_number IS NOT NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "to_address_hash_confirmed_transactions_index"
      )
    )

    create(
      index(
        :transactions,
        [:created_contract_address_hash, "block_number DESC", "index DESC"],
        where: "block_number IS NOT NULL AND (error IS NULL OR (error != 'dropped/replaced'))",
        name: "created_contract_address_hash_confirmed_transactions_index"
      )
    )
  end
end
