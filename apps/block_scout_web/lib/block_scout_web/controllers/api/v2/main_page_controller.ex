defmodule BlockScoutWeb.API.V2.MainPageController do
  use Phoenix.Controller

  alias Explorer.{Chain, PagingOptions}
  alias BlockScoutWeb.API.V2.{BlockView, TransactionView}
  alias Explorer.{Chain, Repo}

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  @transactions_options [
    necessity_by_association: %{
      :block => :required,
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    },
    paging_options: %PagingOptions{page_size: 6},
    api?: true
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def blocks(conn, _params) do
    blocks =
      [paging_options: %PagingOptions{page_size: 4}, api?: true]
      |> Chain.list_blocks()
      |> Repo.replica().preload([[miner: :names], :transactions, :rewards])

    conn
    |> put_status(200)
    |> put_view(BlockView)
    |> render(:blocks, %{blocks: blocks})
  end

  def transactions(conn, _params) do
    recent_transactions = Chain.recent_collated_transactions(false, @transactions_options)

    conn
    |> put_status(200)
    |> put_view(TransactionView)
    |> render(:transactions, %{transactions: recent_transactions})
  end

  def watchlist_transactions(conn, _params) do
    with {:auth, %{watchlist_id: watchlist_id}} <- {:auth, current_user(conn)} do
      {watchlist_names, transactions} = Chain.fetch_watchlist_transactions(watchlist_id, @transactions_options)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions_watchlist, %{transactions: transactions, watchlist_names: watchlist_names})
    end
  end

  def indexing_status(conn, _params) do
    indexed_ratio_blocks = Chain.indexed_ratio_blocks()
    finished_indexing_blocks = Chain.finished_indexing_from_ratio?(indexed_ratio_blocks)

    json(conn, %{
      finished_indexing_blocks: finished_indexing_blocks,
      finished_indexing: Chain.finished_indexing?(api?: true),
      indexed_blocks_ratio: indexed_ratio_blocks,
      indexed_internal_transactions_ratio: if(finished_indexing_blocks, do: Chain.indexed_ratio_internal_transactions())
    })
  end
end
