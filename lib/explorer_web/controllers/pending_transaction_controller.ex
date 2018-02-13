defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.PendingTransactionForm

  def index(conn, params) do
    query = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      inner_join: to_address in assoc(transaction, :to_address),
      inner_join: from_address in assoc(transaction, :from_address),
      preload: [to_address: to_address, from_address: from_address],
      order_by: [desc: transaction.inserted_at],
      where: is_nil(receipt.transaction_id)
    total_query = from transaction in Transaction,
      select: fragment("count(?)", transaction.id),
      left_join: receipt in assoc(transaction, :receipt),
      where: is_nil(receipt.transaction_id)

    transactions = Repo.paginate(
      query,
      params
      |> Map.put(:total_entries, Repo.one(total_query))
      |> Map.put(:page_size, 25)
    )
    entries = transactions.entries |> Enum.map(&PendingTransactionForm.build/1)
    render(
      conn,
      "index.html",
      transactions: Map.put(transactions, :entries, entries)
     )
  end
end
