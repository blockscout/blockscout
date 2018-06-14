defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, PagingOptions}
  # alias Explorer.Chain.Hash

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

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

  defp paging_options(params) do
    with %{"inserted_at" => inserted_at_string, "hash" => hash_string} <- params,
         {:ok, inserted_at, _} <- DateTime.from_iso8601(inserted_at_string),
         {:ok, hash} <- Chain.string_to_transaction_hash(hash_string) do
      [paging_options: %{@default_paging_options | key: {inserted_at, hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end
end
