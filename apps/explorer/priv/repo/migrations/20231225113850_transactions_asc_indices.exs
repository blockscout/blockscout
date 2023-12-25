defmodule Explorer.Repo.Migrations.TransactionsAscIndices do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        [
          :from_address_hash,
          "block_number ASC NULLS FIRST",
          "index ASC NULLS FIRST",
          "inserted_at ASC",
          "hash ASC"
        ],
        name: "transactions_from_address_hash_with_pending_index_asc"
      )
    )

    create(
      index(
        :transactions,
        [
          :to_address_hash,
          "block_number ASC NULLS FIRST",
          "index ASC NULLS FIRST",
          "inserted_at ASC",
          "hash ASC"
        ],
        name: "transactions_to_address_hash_with_pending_index_asc"
      )
    )

    create(
      index(
        :transactions,
        [
          :created_contract_address_hash,
          "block_number ASC NULLS FIRST",
          "index ASC NULLS FIRST",
          "inserted_at ASC",
          "hash ASC"
        ],
        name: "transactions_created_contract_address_hash_with_pending_index_a"
      )
    )
  end
end
