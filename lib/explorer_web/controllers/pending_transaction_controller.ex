defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, params) do
    query = from transaction in Transaction,
      left_join: block_transaction in assoc(transaction, :block_transaction),
      left_join: block in assoc(block_transaction, :block),
      left_join: to_address_join in assoc(transaction, :to_address_join),
      left_join: to_address in assoc(to_address_join, :address),
      left_join: from_address_join in assoc(transaction, :from_address_join),
      left_join: from_address in assoc(from_address_join, :address),
      preload: [
        block: block,
        to_address: to_address,
        from_address: from_address
      ],
      order_by: [desc: transaction.inserted_at],
      where: is_nil(block_transaction.transaction_id)

    transactions = query |> Repo.paginate(params)

    render(
      conn, 
      "index.html", 
      transactions: 
        transactions
        |> Map.put(:entries, transactions.entries
        |> Enum.map(&TransactionForm.build/1))
     )
  end
end
