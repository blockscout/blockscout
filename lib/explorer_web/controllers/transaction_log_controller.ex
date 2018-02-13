defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Log
  alias Explorer.Repo.NewRelic, as: Repo

  def index(conn, params) do
    hash = params["transaction_id"]
    logs = from log in Log,
      join: transaction in assoc(log, :transaction),
      preload: [:address],
      where: transaction.hash == ^hash
    render(conn, "index.html", logs: Repo.paginate(logs), transaction_id: hash)
  end
end
