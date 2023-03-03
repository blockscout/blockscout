defmodule BlockScoutWeb.API.V2.MainPageController do
  use Phoenix.Controller

  alias Explorer.{Chain, PagingOptions}
  alias BlockScoutWeb.API.V2.{BlockView, TransactionView}
  alias Explorer.{Chain, Repo}

  def blocks(conn, _params) do
    blocks =
      [paging_options: %PagingOptions{page_size: 4}]
      |> Chain.list_blocks()
      |> Repo.preload([[miner: :names], :transactions, :rewards])

    conn
    |> put_status(200)
    |> put_view(BlockView)
    |> render(:blocks, %{blocks: blocks})
  end

  def transactions(conn, _params) do
    recent_transactions =
      Chain.recent_collated_transactions(false,
        necessity_by_association: %{
          :block => :required,
          [created_contract_address: :names] => :optional,
          [from_address: :names] => :optional,
          [to_address: :names] => :optional,
          [created_contract_address: :smart_contract] => :optional,
          [from_address: :smart_contract] => :optional,
          [to_address: :smart_contract] => :optional
        },
        paging_options: %PagingOptions{page_size: 6}
      )

    conn
    |> put_status(200)
    |> put_view(TransactionView)
    |> render(:transactions, %{transactions: recent_transactions})
  end

  def indexing_status(conn, _params) do
    indexed_ratio_blocks = Chain.indexed_ratio_blocks()
    finished_indexing_blocks = Chain.finished_blocks_indexing?(indexed_ratio_blocks)

    json(conn, %{
      finished_indexing_blocks: finished_indexing_blocks,
      finished_indexing: Chain.finished_indexing?(indexed_ratio_blocks),
      indexed_blocks_ratio: indexed_ratio_blocks,
      indexed_internal_transactions_ratio: if(finished_indexing_blocks, do: Chain.indexed_ratio_internal_transactions())
    })
  end
end
