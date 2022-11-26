defmodule Explorer.Repo.Migrations.AddTxsIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :transactions,
        [
          :from_address_hash,
          "block_number DESC NULLS FIRST",
          "index DESC NULLS FIRST",
          "inserted_at DESC",
          "hash DESC"
        ],
        name: "transactions_from_address_hash_with_pending_index",
        concurrently: true
      )
    )

    create(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", "inserted_at DESC", "hash DESC"],
        name: "transactions_to_address_hash_with_pending_index",
        concurrently: true
      )
    )

    create(
      index(
        :transactions,
        [
          :created_contract_address_hash,
          "block_number DESC NULLS FIRST",
          "index DESC NULLS FIRST",
          "inserted_at DESC",
          "hash DESC"
        ],
        name: "transactions_created_contract_address_hash_with_pending_index",
        concurrently: true
      )
    )
  end
end
