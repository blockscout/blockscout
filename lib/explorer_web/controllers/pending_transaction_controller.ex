defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction

  def index(conn, params) do
    query = from transaction in Transaction,
      left_join: block_transaction in assoc(transaction, :block_transaction),
      order_by: [desc: transaction.inserted_at],
      where: is_nil(block_transaction.transaction_id)

    render(conn, "index.html", transactions: Repo.paginate(query, params))
  end
end
