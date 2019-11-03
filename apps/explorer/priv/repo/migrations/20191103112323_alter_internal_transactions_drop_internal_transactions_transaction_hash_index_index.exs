defmodule Explorer.Repo.Migrations.AlterInternalTransactionsDropInternalTransactionsTransactionHashIndexIndex do
  use Ecto.Migration

  def change do
    drop(
      index(
        :internal_transactions,
        [:transaction_hash, :index],
        name: :internal_transactions_transaction_hash_index_index
      )
    )
  end
end
