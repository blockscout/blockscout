defmodule ExplorerWeb.TransactionController do
  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  import Ecto.Query

  use ExplorerWeb, :controller

  def index(conn, params) do
    transactions = from t in Transaction,
      join: b in Block, on: b.id == t.block_id,
      order_by: [desc: b.number],
      preload: :block

    render(conn, "index.html", transactions: Repo.paginate(transactions, params))
  end

  def show(conn, params) do
    transaction = Transaction
      |> where(hash: ^params["id"])
      |> first
      |> Repo.one
      |> Repo.preload(:block)
      |> TransactionForm.build
    render(conn, "show.html", transaction: transaction)
  end
end
