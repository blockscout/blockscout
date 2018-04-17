defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Transaction
  alias ExplorerWeb.PendingTransactionForm

  def index(conn, %{"last_seen" => last_seen_id} = _) do
    total = Chain.transaction_count(pending: true)

    entries =
      last_seen_id
      |> Chain.transactions_recently_before_id(
        necessity_by_association: %{
          from_address: :optional,
          to_address: :optional
        },
        pending: true
      )
      |> Enum.map(&PendingTransactionForm.build/1)

    last = List.last(entries) || Transaction.null()

    render(
      conn,
      "index.html",
      transactions: %{
        entries: entries,
        total_entries: total,
        last_seen: last.id
      }
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
