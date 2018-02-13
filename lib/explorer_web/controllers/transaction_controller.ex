defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, params) do
    query = from transaction in Transaction,
      join: receipt in assoc(transaction, :receipt),
      join: block in assoc(transaction, :block),
      preload: [block: block, receipt: receipt],
      order_by: [desc: block.timestamp]

    transactions = Repo.paginate(query, params)

    render(conn, "index.html", transactions: transactions)
  end

  def show(conn, params) do
    hash = String.downcase(params["id"])
    query = from transaction in Transaction,
      left_join: block_transaction in assoc(transaction, :block_transaction),
      left_join: receipt in assoc(transaction, :receipt),
      left_join: block in assoc(block_transaction, :block),
      left_join: to_address_join in assoc(transaction, :to_address_join),
      left_join: to_address in assoc(to_address_join, :address),
      left_join: from_address_join in assoc(transaction, :from_address_join),
      left_join: from_address in assoc(from_address_join, :address),
      preload: [
        block: block,
        receipt: receipt,
        to_address: to_address,
        from_address: from_address
      ],
      where: fragment("lower(?)", transaction.hash) == ^hash,
      limit: 1

    transaction = query |> Repo.one |> TransactionForm.build

    render(conn, "show.html", transaction: transaction)
  end
end
