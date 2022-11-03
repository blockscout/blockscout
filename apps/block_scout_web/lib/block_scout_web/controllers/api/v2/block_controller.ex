defmodule BlockScoutWeb.API.V2.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [next_page_params: 3, paging_options: 1, put_key_value_to_paging_options: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper, only: [select_block_type: 1]

  alias BlockScoutWeb.API.V2.TransactionView
  alias BlockScoutWeb.BlockTransactionController
  alias Explorer.Chain

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      :block => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def block(conn, %{"block_hash_or_number" => block_hash_or_number}) do
    with {:ok, block} <-
           BlockTransactionController.param_block_hash_or_number_to_block(block_hash_or_number,
             necessity_by_association: %{
               [miner: :names] => :required,
               :uncles => :optional,
               :nephews => :optional,
               :rewards => :optional,
               :transactions => :optional
             }
           ) do
      conn
      |> put_status(200)
      |> render(:block, %{block: block})
    end
  end

  def blocks(conn, params) do
    full_options = select_block_type(params)

    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Chain.list_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    next_page_params = next_page_params(next_page, blocks, params)

    conn
    |> put_status(200)
    |> render(:blocks, %{blocks: blocks, next_page_params: next_page_params})
  end

  def transactions(conn, %{"block_hash_or_number" => block_hash_or_number} = params) do
    with {:ok, block} <- BlockTransactionController.param_block_hash_or_number_to_block(block_hash_or_number, []) do
      full_options =
        Keyword.merge(
          @transaction_necessity_by_association,
          put_key_value_to_paging_options(paging_options(params), :is_index_in_asc_order, true)
        )

      transactions_plus_one = Chain.block_to_transactions(block.hash, full_options, false)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params = next_page_params(next_page, transactions, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
    end
  end
end
