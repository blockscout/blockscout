defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Transaction
  alias Explorer.Repo
  alias Explorer.TransactionForm

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
