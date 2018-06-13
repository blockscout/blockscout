defmodule ExplorerWeb.BlockTransactionController do
  use ExplorerWeb, :controller

  import ExplorerWeb.Chain, only: [param_to_block_number: 1]

  alias Explorer.{Chain, PagingOptions}

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

  def index(conn, %{"block_id" => formatted_block_number} = params) do
    with {:ok, block_number} <- param_to_block_number(formatted_block_number),
         {:ok, block} <- Chain.number_to_block(block_number, necessity_by_association: %{miner: :required}),
         block_transaction_count <- Chain.block_to_transaction_count(block) do
      full_options =
        [
          necessity_by_association: %{
            block: :required,
            from_address: :required,
            to_address: :optional
          }
        ]
        |> Keyword.merge(paging_options(params))

      transactions_plus_one = Chain.block_to_transactions(block, full_options)

      {transactions, next_page} = Enum.split(transactions_plus_one, @page_size)

      render(
        conn,
        "index.html",
        block: block,
        block_transaction_count: block_transaction_count,
        next_page_params: next_page_params(next_page, transactions),
        transactions: transactions
      )
    else
      {:error, :invalid} ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp next_page_params([], _transactions), do: nil

  defp next_page_params(_, transactions) do
    last = List.last(transactions)
    %{block_number: last.block_number, index: last.index}
  end

  defp paging_options(params) do
    with %{"index" => index_string} <- params,
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end
end
