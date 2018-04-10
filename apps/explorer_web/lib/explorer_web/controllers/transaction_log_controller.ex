defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Log
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.Transaction.Service.Query
  alias ExplorerWeb.TransactionForm

  def index(conn, %{"transaction_id" => transaction_id}) do
    transaction_hash = String.downcase(transaction_id)
    transaction = get_transaction(transaction_hash)

    logs =
      from(
        log in Log,
        join: transaction in assoc(log, :transaction),
        preload: [:address],
        where: fragment("lower(?)", transaction.hash) == ^transaction_hash
      )

    render(
      conn,
      "index.html",
      logs: Repo.paginate(logs),
      transaction: transaction
    )
  end

  defp get_transaction(hash) do
    Transaction
    |> Query.by_hash(hash)
    |> Query.include_addresses()
    |> Query.include_receipt()
    |> Query.include_block()
    |> Repo.one()
    |> TransactionForm.build_and_merge()
  end
end
