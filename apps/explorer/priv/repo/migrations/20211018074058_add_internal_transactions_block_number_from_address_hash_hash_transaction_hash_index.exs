defmodule Explorer.Repo.Migrations.AddInternalTransactionsBlockNumberFromAddressHashHashTransactionHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :internal_transactions,
        ~w(block_number from_address_hash transaction_hash)a,
        concurrently: true
      )
    )
  end
end
