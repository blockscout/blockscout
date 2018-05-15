defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, params) do
    with %{"last_seen_pending_inserted_at" => last_seen_pending_inserted_at_string} <- params,
         {:ok, last_seen_pending_inserted_at} = Timex.parse(last_seen_pending_inserted_at_string, "{ISO:Extended:Z}") do
      do_index(conn, inserted_after: last_seen_pending_inserted_at)
    else
      _ -> do_index(conn)
    end
  end

  defp do_index(conn, options \\ []) when is_list(options) do
    full_options = Keyword.merge([necessity_by_association: %{from_address: :optional, to_address: :optional}], options)
    transactions = Chain.recent_pending_transactions(full_options)
    last_seen_pending_inserted_at = last_seen_pending_inserted_at(transactions.entries)
    transaction_count = Chain.transaction_count(pending: true)

    render(
      conn,
      "index.html",
      last_seen_pending_inserted_at: last_seen_pending_inserted_at,
      transaction_count: transaction_count,
      transactions: transactions
    )
  end

  defp last_seen_pending_inserted_at([]), do: nil

  defp last_seen_pending_inserted_at(transactions) do
    List.last(transactions).inserted_at
  end
end
