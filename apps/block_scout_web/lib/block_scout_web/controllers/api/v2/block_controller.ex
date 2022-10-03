defmodule BlockScoutWeb.API.V2.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper,
    only: [paging_options: 2, filter_options: 1, method_filter_options: 1, type_filter_options: 1]

  alias BlockScoutWeb.BlockTransactionController
  alias Explorer.Chain
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Runner.InternalTransactions

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def block(conn, %{"block_hash_or_number" => block_hash_or_number}) do
    with {:ok, block} <-
            BlockTransactionController.param_block_hash_or_number_to_block(block_hash_or_number,
              necessity_by_association: %{
                [miner: :names] => :required,
                :uncles => :optional,
                :nephews => :optional,
                :rewards => :optional
              }
            ) do
      block_transaction_count = Chain.block_to_transaction_count(block.hash)

      conn
      |> put_status(200)
      |> render(:block, %{block: block, tx_count: block_transaction_count})
    end
  end
end
