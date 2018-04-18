defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  def index(conn, %{"last_seen" => last_seen_id} = _) do
    total = Chain.transaction_count(pending: true)

    transactions =
      Chain.transactions_recently_before_id(
        last_seen_id,
        necessity_by_association: %{from_address: :optional, to_address: :optional},
        pending: true
      )

    last_seen_transaction_id =
      case transactions do
        [] ->
          nil

        _ ->
          transactions
          |> Stream.map(fn %Transaction{id: id} -> id end)
          |> Enum.max()
      end

    render(
      conn,
      "index.html",
      last_seen_transaction_id: last_seen_transaction_id,
      transaction_count: total,
      transactions: transactions
    )
  end

  def index(conn, params) do
    last_seen =
      [pending: true]
      |> Chain.last_transaction_id()
      |> Kernel.+(1)
      |> Integer.to_string()

    index(conn, Map.put(params, "last_seen", last_seen))
  end
end
