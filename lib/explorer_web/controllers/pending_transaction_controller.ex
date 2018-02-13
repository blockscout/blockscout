defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.PendingTransactionForm

  def index(conn, params) do
    query = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      left_join: block_transaction in assoc(transaction, :block_transaction),
      join: to_address in assoc(transaction, :to_address),
      join: from_address in assoc(transaction, :from_address),
      preload: [to_address: to_address, from_address: from_address],
      order_by: [desc: transaction.inserted_at],
      where: is_nil(receipt.transaction_id)

    transactions = query |> Repo.paginate(params)
    render(
      conn,
      "index.html",
      transactions:
        transactions
        |> Map.put(:entries, transactions.entries
        |> Enum.map(&PendingTransactionForm.build/1))
     )
  end
end
