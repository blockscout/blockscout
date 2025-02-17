defmodule BlockScoutWeb.API.V2.MainPageController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.{Chain, PagingOptions}
  alias BlockScoutWeb.API.V2.{BlockView, OptimismView, TransactionView}
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Optimism.Deposit

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  case @chain_type do
    :celo ->
      @chain_type_transaction_necessity_by_association %{
        :gas_token => :optional
      }

    _ ->
      @chain_type_transaction_necessity_by_association %{}
  end

  @transactions_options [
    necessity_by_association:
      %{
        :block => :required,
        [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
          :optional,
        [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
        [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
      }
      |> Map.merge(@chain_type_transaction_necessity_by_association),
    paging_options: %PagingOptions{page_size: 6},
    api?: true
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def blocks(conn, _params) do
    blocks =
      [paging_options: %PagingOptions{page_size: 4}, api?: true]
      |> Chain.list_blocks()
      |> Repo.replica().preload([
        [miner: [:names, :smart_contract, proxy_implementations_association()]],
        :transactions,
        :rewards
      ])

    conn
    |> put_status(200)
    |> put_view(BlockView)
    |> render(:blocks, %{blocks: blocks |> maybe_preload_ens() |> maybe_preload_metadata()})
  end

  def optimism_deposits(conn, _params) do
    recent_deposits =
      Deposit.list(
        paging_options: %PagingOptions{page_size: 6},
        api?: true
      )

    conn
    |> put_status(200)
    |> put_view(OptimismView)
    |> render(:optimism_deposits, %{deposits: recent_deposits})
  end

  def transactions(conn, _params) do
    recent_transactions = Chain.recent_collated_transactions(false, @transactions_options)

    conn
    |> put_status(200)
    |> put_view(TransactionView)
    |> render(:transactions, %{transactions: recent_transactions |> maybe_preload_ens() |> maybe_preload_metadata()})
  end

  def watchlist_transactions(conn, _params) do
    with {:auth, %{watchlist_id: watchlist_id}} <- {:auth, current_user(conn)} do
      {watchlist_names, transactions} = Chain.fetch_watchlist_transactions(watchlist_id, @transactions_options)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions_watchlist, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        watchlist_names: watchlist_names
      })
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
