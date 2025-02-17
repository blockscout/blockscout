defmodule Explorer.Repo.Migrations.AddTransactionsIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists(
      index(
        :transactions,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_from_address_hash_recent_collated_index",
        concurrently: true
      )
    )

    drop_if_exists(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_to_address_hash_recent_collated_index",
        concurrently: true
      )
    )

    drop_if_exists(
      index(
        :transactions,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_created_contract_address_hash_recent_collated_index",
        concurrently: true
      )
    )

    create_if_not_exists(
      index(
        :transactions,
        [
          :from_address_hash,
          "block_number DESC NULLS FIRST",
          "index DESC NULLS FIRST",
          "inserted_at DESC",
          "hash ASC"
        ],
        name: "transactions_from_address_hash_with_pending_index",
        concurrently: true
      )
    )

    create_if_not_exists(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", "inserted_at DESC", "hash ASC"],
        name: "transactions_to_address_hash_with_pending_index",
        concurrently: true
      )
    )

    create_if_not_exists(
      index(
        :transactions,
        [
          :created_contract_address_hash,
          "block_number DESC NULLS FIRST",
          "index DESC NULLS FIRST",
          "inserted_at DESC",
          "hash ASC"
        ],
        name: "transactions_created_contract_address_hash_with_pending_index",
        concurrently: true
      )
    )
  end
end
