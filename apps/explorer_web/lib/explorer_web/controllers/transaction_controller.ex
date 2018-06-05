defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, PagingOptions}

  def index(conn, params) do
    case params do
      %{"block_number" => block_number, "index" => index} ->
        do_index(conn, paging_options: %PagingOptions{key: {block_number, index}, page_size: 50})

      _ ->
        do_index(conn)
    end
  end

  def show(conn, %{"id" => id, "locale" => locale}) do
    redirect(conn, to: transaction_internal_transaction_path(conn, :index, locale, id))
  end

  defp do_index(conn, options \\ [paging_options: %PagingOptions{page_size: 50}]) when is_list(options) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            block: :required,
            from_address: :optional,
            to_address: :optional
          }
        ],
        options
      )

    transactions = Chain.recent_collated_transactions(full_options)
    transaction_count = Chain.transaction_count()

    render(
      conn,
      "index.html",
      earliest: earliest(transactions),
      transaction_count: transaction_count,
      transactions: transactions
    )
  end

  defp earliest([]), do: nil

  defp earliest(transactions) do
    last = List.last(transactions)
    %{block_number: last.block_number, index: last.index}
  end
end
