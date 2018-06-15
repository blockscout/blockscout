defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import ExplorerWeb.Chain, only: [paging_options: 1]

  alias Explorer.Chain

  @page_size 50

  def index(conn, params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            from_address: :optional,
            to_address: :optional
          }
        ],
        paging_options(params)
      )

    transactions_plus_one = Chain.recent_pending_transactions(full_options)

    {transactions, next_page} = Enum.split(transactions_plus_one, @page_size)

    pending_transaction_count = Chain.pending_transaction_count()

    render(
      conn,
      "index.html",
      next_page_params: next_page_params(next_page, transactions),
      pending_transaction_count: pending_transaction_count,
      transactions: transactions
    )
  end

  defp next_page_params([], _transactions), do: nil

  defp next_page_params(_, transactions) do
    last = List.last(transactions)
    %{inserted_at: DateTime.to_iso8601(last.inserted_at), hash: last.hash}
  end
end
