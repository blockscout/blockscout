defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, params) do
    query = from transaction in Transaction,
      join: block_transaction in assoc(transaction, :block_transaction),
      join: block in assoc(block_transaction, :block),
      preload: [block: block],
      order_by: [desc: block.timestamp]

    transactions = Repo.paginate(query, params)

    render(conn, "index.html", transactions: transactions)
  end

  def show(conn, params) do
    hash = String.downcase(params["id"])
    query = from transaction in Transaction,
      left_join: block_transaction in assoc(transaction, :block_transaction),
      left_join: block in assoc(block_transaction, :block),
      preload: [block_transaction: block_transaction, block: block],
      where: fragment("lower(?)", transaction.hash) == ^hash,
      limit: 1

    transaction = query |> Repo.one |> TransactionForm.build

    render(conn, "show.html", transaction: transaction)
  end
end
