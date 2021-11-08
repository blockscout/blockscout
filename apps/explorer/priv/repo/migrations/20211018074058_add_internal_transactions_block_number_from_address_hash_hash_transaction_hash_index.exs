defmodule Explorer.Repo.Migrations.AddInternalTransactionsBlockNumberFromToCreatedAddressHashTransactionHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :internal_transactions,
        ~w(block_number from_address_hash transaction_hash)a
      )
    )

    create(
      index(
        :internal_transactions,
        ~w(block_number to_address_hash transaction_hash)a
      )
    )

    create(
      index(
        :internal_transactions,
        ~w(block_number created_contract_address_hash transaction_hash)a
      )
    )
  end
end
