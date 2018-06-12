defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, PagingOptions}

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

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

    transactions_plus_one = Chain.recent_collated_transactions(full_options)

    {next_page, transactions} = List.pop_at(transactions_plus_one, @page_size)

    transaction_estimated_count = Chain.transaction_estimated_count()

    render(
      conn,
      "index.html",
      next_page_params: next_page_params(next_page, transactions),
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions
    )
  end

  defp next_page_params(nil, _transactions), do: nil

  defp next_page_params(_, transactions) do
    last = List.last(transactions)
    %{block_number: last.block_number, index: last.index}
  end
end
