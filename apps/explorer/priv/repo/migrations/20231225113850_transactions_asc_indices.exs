defmodule Explorer.Repo.Migrations.TransactionsAscIndices do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        [
          :from_address_hash,
          "block_number ASC NULLS LAST",
          "index ASC NULLS LAST",
          "inserted_at ASC",
          "hash DESC"
        ],
        name: "transactions_from_address_hash_with_pending_index_asc"
      )
    )

    create(
      index(
        :transactions,
        [
          :to_address_hash,
          "block_number ASC NULLS LAST",
          "index ASC NULLS LAST",
          "inserted_at ASC",
          "hash DESC"
        ],
        name: "transactions_to_address_hash_with_pending_index_asc"
      )
    )

    create(
      index(
        :transactions,
        [
          :created_contract_address_hash,
          "block_number ASC NULLS LAST",
          "index ASC NULLS LAST",
          "inserted_at ASC",
          "hash DESC"
        ],
        name: "transactions_created_contract_address_hash_with_pending_index_a"
      )
    )
  end
end
