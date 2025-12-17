defmodule BlockScoutWeb.API.V2.MainPageController do
  use BlockScoutWeb, :controller

  use Utils.CompileTimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.API.V2.{BlockView, TransactionView}
  alias Explorer.{Chain, PagingOptions, Repo}

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]
  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]

  case @chain_identity do
    {:optimism, :celo} ->
      @chain_type_transaction_necessity_by_association %{
        [gas_token: reputation_association()] => :optional
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

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["main_page"])

  operation :blocks,
    summary: "Retrieve recent blocks as displayed on Blockscout homepage",
    description: "Retrieves a limited set of recent blocks for display on the main page or dashboard.",
    parameters: base_params(),
    responses: [
      ok:
        {"List of recent blocks on the home page.", "application/json",
         %Schema{
           type: :array,
           items: Schemas.Block.Response,
           nullable: false
         }}
    ]

  @doc """
  Returns the last 4 blocks for display on the main page.
  """
  @spec blocks(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
    |> render(:blocks, %{blocks: blocks |> maybe_preload_metadata()})
  end

  operation :transactions,
    summary: "Retrieve recent transactions as displayed on Blockscout homepage",
    description: "Retrieves a limited set of recent transactions displayed on the home page.",
    parameters: base_params(),
    responses: [
      ok:
        {"List of recent transactions on the home page.", "application/json",
         %Schema{
           type: :array,
           items: Schemas.Transaction.Response,
           nullable: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns the last 6 transactions for display on the main page.
  """
  @spec transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transactions(conn, _params) do
    recent_transactions = Chain.recent_collated_transactions(false, @transactions_options)

    conn
    |> put_status(200)
    |> put_view(TransactionView)
    |> render(:transactions, %{transactions: recent_transactions |> maybe_preload_metadata()})
  end

  operation :watchlist_transactions,
    summary: "Last 6 transactions from the current user's watchlist",
    description: "Retrieves a list of last 6 transactions from the current user's watchlist.",
    parameters: base_params(),
    responses: [
      ok:
        {"List of watchlist transactions", "application/json",
         %Schema{
           type: :array,
           items: Schemas.Transaction.Response,
           nullable: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns the last 6 watchlist transactions for display on the main page.
  """
  @spec watchlist_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def watchlist_transactions(conn, _params) do
    with {:auth, %{watchlist_id: watchlist_id}} <- {:auth, current_user(conn)} do
      {watchlist_names, transactions} = Chain.fetch_watchlist_transactions(watchlist_id, @transactions_options)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions_watchlist, %{
        transactions: transactions |> maybe_preload_metadata(),
        watchlist_names: watchlist_names
      })
    end
  end

  operation :indexing_status,
    summary: "Check if indexing is finished with indexing ratio",
    description: "Retrieves the current status of blockchain data indexing by the BlockScout instance.",
    parameters: base_params(),
    responses: [
      ok:
        {"Current blockchain indexing status.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             finished_indexing_blocks: %Schema{type: :boolean},
             finished_indexing: %Schema{type: :boolean},
             indexed_blocks_ratio: %Schema{type: :number, format: :float},
             indexed_internal_transactions_ratio: %Schema{type: :number, format: :float, nullable: true}
           }
         }}
    ]

  @doc """
  Lists the indexing status of blocks and transactions.
  """
  @spec indexing_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
