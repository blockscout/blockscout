defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Log
  alias Explorer.Repo.NewRelic, as: Repo

  def index(conn, %{"transaction_id" => transaction_id}) do
    hash = String.downcase(transaction_id)
    logs = from log in Log,
      join: transaction in assoc(log, :transaction),
      preload: [:address],
      where: fragment("lower(?)", transaction.hash) == ^hash
    render(conn, "index.html", logs: Repo.paginate(logs), transaction_hash: hash)
  end
end
