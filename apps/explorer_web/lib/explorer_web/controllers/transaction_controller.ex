defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, PagingOptions}

  @default_paging_options %PagingOptions{page_size: 50}

  def index(conn, %{"block_number" => block_number_string, "index" => index_string}) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {index, ""} <- Integer.parse(index_string) do
      do_index(conn, paging_options: %{@default_paging_options | key: {block_number, index}})
    else
      _ ->
        unprocessable_entity(conn)
    end
  end

  def index(conn, _params) do
    do_index(conn)
  end

  def show(conn, %{"id" => id, "locale" => locale}) do
    redirect(conn, to: transaction_internal_transaction_path(conn, :index, locale, id))
  end

  defp do_index(conn, options \\ []) when is_list(options) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            block: :required,
            from_address: :optional,
            to_address: :optional
          },
          paging_options: @default_paging_options
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
