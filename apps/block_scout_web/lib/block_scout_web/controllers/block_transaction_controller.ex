defmodule BlockScoutWeb.BlockTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, param_to_block_number: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain

  def index(conn, %{"block_id" => formatted_block_number} = params) do
    with {:ok, block_number} <- param_to_block_number(formatted_block_number),
         {:ok, block} <- Chain.number_to_block(block_number, necessity_by_association: %{miner: :required}),
         block_transaction_count <- Chain.block_to_transaction_count(block) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              :block => :required,
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :required,
              [to_address: :names] => :optional
            }
          ],
          paging_options(params)
        )

      transactions_plus_one = Chain.block_to_transactions(block, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      render(
        conn,
        "index.html",
        block: block,
        block_transaction_count: block_transaction_count,
        next_page_params: next_page_params(next_page, transactions, params),
        transactions: transactions
      )
    else
      {:error, :invalid} ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
