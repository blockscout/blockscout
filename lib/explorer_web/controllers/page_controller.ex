defmodule ExplorerWeb.PageController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Block
  alias Explorer.Transaction
  alias Explorer.Repo

  def index(conn, _params) do
    blocks = Block
      |> order_by(desc: :number)
      |> limit(5)
      |> Repo.all

    transactions = Transaction
      |> join(:left, [t, b], b in assoc(t, :block))
      |> order_by([t, b], desc: b.timestamp)
      |> limit(5)
      |> Repo.all
      |> Repo.preload(:block)

    render(conn, "index.html", blocks: blocks, transactions: transactions)
  end
end
