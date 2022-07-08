defmodule Explorer.Repo.Migrations.AddInternalTransactionsBlockNumberFromToCreatedAddressHashTransactionHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :internal_transactions,
        ~w(block_number from_address_hash transaction_hash)a,
        concurrently: true
      )
    )

    create(
      index(
        :internal_transactions,
        ~w(block_number to_address_hash transaction_hash)a,
        concurrently: true
      )
    )

    create(
      index(
        :internal_transactions,
        ~w(block_number created_contract_address_hash transaction_hash)a,
        concurrently: true
      )
    )
  end
end
