defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  use Utils.CompileTimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      next_page_params: 4,
      next_page_params: 5,
      put_key_value_to_paging_options: 3,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      fetch_scam_token_toggle: 2,
      transaction_to_internal_transactions: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      paging_options: 2,
      filter_options: 2,
      method_filter_options: 1,
      token_transfers_types_options: 1,
      type_filter_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1, maybe_preload_ens_to_transaction: 1]

  import Explorer.MicroserviceInterfaces.Metadata,
    only: [maybe_preload_metadata: 1, maybe_preload_metadata_to_transaction: 1]

  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]

  import Ecto.Query,
    only: [
      preload: 2
    ]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.{BlobView, Ethereum.DepositController, Ethereum.DepositView}
  alias BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation, as: TransactionInterpretationService
  alias BlockScoutWeb.Models.TransactionStateHelper
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.{ForbiddenResponse, NotFoundResponse}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.Arbitrum.Reader.API.Settlement, as: ArbitrumSettlementReader
  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit
  alias Explorer.Chain.Beacon.Reader, as: BeaconReader
  alias Explorer.Chain.Cache.Counters.{NewPendingTransactionsCount, Transactions24hCount}
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Optimism.TransactionBatch, as: OptimismTransactionBatch
  alias Explorer.Chain.PolygonZkevm.Reader, as: PolygonZkevmReader
  alias Explorer.Chain.Scroll.Reader, as: ScrollReader
  alias Explorer.Chain.Token.Instance
  alias Explorer.Chain.ZkSync.Reader, as: ZkSyncReader
  alias Indexer.Fetcher.OnDemand.FirstTrace, as: FirstTraceOnDemand
  alias Indexer.Fetcher.OnDemand.NeonSolanaTransactions, as: NeonSolanaTransactions

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["transactions"])

  case @chain_identity do
    {:ethereum, nil} ->
      @chain_type_transaction_necessity_by_association %{
        :beacon_blob_transaction => :optional
      }

    {:optimism, :celo} ->
      @chain_type_transaction_necessity_by_association %{
        [gas_token: reputation_association()] => :optional
      }

    _ ->
      @chain_type_transaction_necessity_by_association %{}
  end

  # TODO might be redundant to preload blob fields in some of the endpoints
  @transaction_necessity_by_association %{
                                          :block => :optional,
                                          [
                                            created_contract_address: [
                                              :scam_badge,
                                              :names,
                                              :token,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional,
                                          [
                                            from_address: [
                                              :scam_badge,
                                              :names,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional,
                                          [
                                            to_address: [
                                              :scam_badge,
                                              :names,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional
                                        }
                                        |> Map.merge(@chain_type_transaction_necessity_by_association)

  @token_transfers_necessity_by_association %{
    [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [token: reputation_association()] => :optional
  }

  @token_transfers_in_transaction_necessity_by_association %{
    [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [token: reputation_association()] => :optional
  }

  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
        :optional,
      [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
    }
  ]

  @api_true [api?: true]

  operation :transaction,
    summary: "Retrieve detailed information about a specific transaction",
    description: "Retrieves detailed information for a specific transaction identified by its hash.",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok: {"Detailed information about the specified transaction.", "application/json", Schemas.Transaction.Response},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param` endpoint.
  """
  @spec transaction(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def transaction(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    necessity_by_association_with_actions =
      @transaction_necessity_by_association
      |> Map.put(:transaction_actions, :optional)
      |> Map.put(:signed_authorizations, :optional)

    necessity_by_association =
      case Application.get_env(:explorer, :chain_type) do
        :polygon_zkevm ->
          necessity_by_association_with_actions
          |> Map.put(:zkevm_batch, :optional)
          |> Map.put(:zkevm_sequence_transaction, :optional)
          |> Map.put(:zkevm_verify_transaction, :optional)

        :zksync ->
          necessity_by_association_with_actions
          |> Map.put(:zksync_batch, :optional)
          |> Map.put(:zksync_commit_transaction, :optional)
          |> Map.put(:zksync_prove_transaction, :optional)
          |> Map.put(:zksync_execute_transaction, :optional)

        :arbitrum ->
          necessity_by_association_with_actions
          |> Map.put(:arbitrum_batch, :optional)
          |> Map.put(:arbitrum_commitment_transaction, :optional)
          |> Map.put(:arbitrum_confirmation_transaction, :optional)
          |> Map.put(:arbitrum_message_to_l2, :optional)
          |> Map.put(:arbitrum_message_from_l2, :optional)

        :suave ->
          necessity_by_association_with_actions
          |> Map.put(:logs, :optional)
          |> Map.put([execution_node: :names], :optional)
          |> Map.put([wrapped_to_address: :names], :optional)

        _ ->
          necessity_by_association_with_actions
      end

    options =
      [necessity_by_association: necessity_by_association]
      |> Keyword.merge(@api_true)

    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options),
         preloaded <-
           Chain.preload_token_transfers(
             transaction,
             @token_transfers_in_transaction_necessity_by_association,
             @api_true |> fetch_scam_token_toggle(conn)
           ) do
      conn
      |> put_status(200)
      |> render(:transaction, %{
        transaction:
          preloaded
          |> Instance.preload_nft(@api_true)
          |> maybe_preload_ens_to_transaction()
          |> maybe_preload_metadata_to_transaction()
      })
    end
  end

  operation :transactions,
    summary: "List blockchain transactions with filtering options for status, type, and method",
    description: "Retrieves a paginated list of transactions with optional filtering by status, type, and method.",
    parameters:
      base_params() ++
        [transaction_filter_param(), transaction_type_param()] ++
        define_paging_params(["block_number", "index", "items_count", "hash", "inserted_at"]),
    responses: [
      ok:
        {"List of transactions with pagination information.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 23_532_302,
             "index" => 375,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions` endpoint.
  """
  @spec transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transactions(conn, params) do
    filter_options = filter_options(params, :validated)

    full_options =
      [
        necessity_by_association: @transaction_necessity_by_association
      ]
      |> Keyword.merge(paging_options(params, filter_options))
      |> Keyword.merge(method_filter_options(params))
      |> Keyword.merge(type_filter_options(params))
      |> Keyword.merge(@api_true)

    transactions_plus_one = Chain.recent_transactions(full_options, filter_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page |> next_page_params(transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation :polygon_zkevm_batch,
    summary: "List L2 transactions in a Polygon ZkEVM batch",
    description: "Retrieves L2 transactions bound to a specific Polygon ZkEVM batch number.",
    parameters: [batch_number_param() | base_params()],
    responses: [
      ok:
        {"Polygon ZkEVM batch transactions.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             items: %Schema{type: :array, items: Schemas.Transaction.Response}
           },
           nullable: false,
           additionalProperties: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/zkevm-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec polygon_zkevm_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def polygon_zkevm_batch(conn, %{batch_number_param: batch_number} = _params) do
    options =
      [necessity_by_association: @transaction_necessity_by_association]
      |> Keyword.merge(@api_true)

    transactions =
      batch_number
      |> PolygonZkevmReader.batch_transactions(@api_true)
      |> Enum.map(fn transaction -> transaction.hash end)
      |> Chain.hashes_to_transactions(options)

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      items: true
    })
  end

  operation :zksync_batch,
    summary: "List L2 transactions in a ZkSync batch",
    description: "Retrieves L2 transactions bound to a specific ZkSync batch number.",
    parameters:
      base_params() ++
        [batch_number_param()] ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"ZkSync batch transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 65_361_291,
             "index" => 1,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/zksync-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec zksync_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zksync_batch(conn, params) do
    handle_batch_transactions(conn, params, &ZkSyncReader.batch_transactions/2)
  end

  operation :arbitrum_batch,
    summary: "List L2 transactions in an Arbitrum batch",
    description: "Retrieves L2 transactions bound to a specific Arbitrum batch number.",
    parameters:
      base_params() ++
        [batch_number_param()] ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Arbitrum batch transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 391_483_842,
             "index" => 0,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/arbitrum-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec arbitrum_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def arbitrum_batch(conn, params) do
    handle_batch_transactions(conn, params, &ArbitrumSettlementReader.batch_transactions/2)
  end

  operation :external_transactions,
    summary: "List external transactions linked to a transaction",
    description:
      "Retrieves external transactions that are linked to the specified transaction (e.g., Solana transactions in `neon` chain type).",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok:
        {"Linked external transactions.", "application/json",
         %Schema{type: :array, items: %Schema{type: :string}, nullable: false}},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/external-transactions` endpoint.
    It renders the list of external transactions that are somehow linked (eg. preceded or initiated by) to the selected one.
    The most common use case is for side-chains and rollups. Currently implemented only for Neon chain but could also be extended for
    similar cases.
  """
  @spec external_transactions(Plug.Conn.t(), %{required(atom()) => String.t()}) :: Plug.Conn.t()
  def external_transactions(conn, %{transaction_hash_param: transaction_hash} = _params) do
    with {:format, {:ok, hash}} <- {:format, Chain.string_to_full_hash(transaction_hash)} do
      case NeonSolanaTransactions.maybe_fetch(hash) do
        {:ok, linked_transactions} ->
          conn
          |> put_status(200)
          |> json(linked_transactions)

        {:error, reason} ->
          Logger.error("Fetching external linked transactions failed: #{inspect(reason)}")

          conn
          |> put_status(500)
          |> json(%{
            error: "Unable to fetch external linked transactions",
            reason: "#{inspect(reason)}"
          })
      end
    end
  end

  operation :optimism_batch,
    summary: "List L2 transactions in an Optimism batch",
    description: "Retrieves L2 transactions bound to a specific Optimism batch number.",
    parameters:
      base_params() ++
        [batch_number_param()] ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Optimism batch transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 142_678_440,
             "index" => 5,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/optimism-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec optimism_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def optimism_batch(conn, %{batch_number_param: batch_number} = params) do
    l2_block_number_from = OptimismTransactionBatch.edge_l2_block_number(batch_number, :min, @api_true)
    l2_block_number_to = OptimismTransactionBatch.edge_l2_block_number(batch_number, :max, @api_true)

    handle_block_range_transactions(conn, params, l2_block_number_from, l2_block_number_to)
  end

  operation :scroll_batch,
    summary: "List L2 transactions in a Scroll batch",
    description: "Retrieves L2 transactions bound to a specific Scroll batch number.",
    parameters:
      base_params() ++
        [batch_number_param()] ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Scroll batch transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 14_127_868,
             "index" => 0,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/scroll-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec scroll_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def scroll_batch(conn, %{batch_number_param: batch_number} = params) do
    {l2_block_number_from, l2_block_number_to} =
      case ScrollReader.batch(batch_number, @api_true) do
        {:ok, batch} -> {batch.l2_block_range.from, batch.l2_block_range.to}
        _ -> {nil, nil}
      end

    handle_block_range_transactions(conn, params, l2_block_number_from, l2_block_number_to)
  end

  # Processes and renders transactions for a specified L2 block range into an HTTP response.
  #
  # This function retrieves a list of transactions for a given L2 block range and formats
  # these transactions into an HTTP response.
  #
  # ## Parameters
  # - `conn`: The connection object.
  # - `params`: Parameters from the request.
  # - `l2_block_number_from`: Start L2 block number of the range.
  # - `l2_block_number_to`: End L2 block number of the range.
  #
  # ## Returns
  # - Updated connection object with the transactions data rendered.
  @spec handle_block_range_transactions(Plug.Conn.t(), map(), non_neg_integer(), non_neg_integer()) :: Plug.Conn.t()
  defp handle_block_range_transactions(conn, params, l2_block_number_from, l2_block_number_to) do
    transactions_plus_one =
      if is_nil(l2_block_number_from) or is_nil(l2_block_number_to) do
        []
      else
        paging_options = paging_options(params)[:paging_options]

        query =
          case paging_options do
            %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} ->
              []

            _ ->
              # here we need to subtract 1 because the block range inside the `fetch_transactions` function
              # starts from the `from_block + 1`
              Transaction.fetch_transactions(paging_options, l2_block_number_from - 1, l2_block_number_to)
          end

        query
        |> Chain.join_associations(@transaction_necessity_by_association)
        |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
        |> Repo.replica().all()
      end

    {transactions, next_page} = split_list_by_page(transactions_plus_one)
    next_page_params = next_page |> next_page_params(transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  # Processes and renders transactions for a specified batch into an HTTP response.
  #
  # This function retrieves a list of transactions for a given batch using a specified function,
  # then extracts the transaction hashes. These hashes are used to retrieve the corresponding
  # `Explorer.Chain.Transaction` records according to the given pagination options. It formats
  # these transactions into an HTTP response.
  #
  # ## Parameters
  # - `conn`: The connection object.
  # - `params`: Parameters from the request, including the batch number.
  # - `batch_transactions_fun`: A function to fetch transaction descriptions for the given batch.
  #
  # ## Returns
  # - Updated connection object with the transactions data rendered.
  @spec handle_batch_transactions(Plug.Conn.t(), map(), function()) :: Plug.Conn.t()
  defp handle_batch_transactions(conn, %{batch_number_param: batch_number} = params, batch_transactions_fun) do
    full_options =
      [
        necessity_by_association: @transaction_necessity_by_association
      ]
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)

    # Although a naive way is to implement pagination on the level of `batch_transactions` call,
    # it will require to re-implement all pagination logic existing in Explorer.Chain.Transaction
    # In order to simplify the code, all transaction are requested from the batch and then
    # only subset of them is returned from `hashes_to_transactions`.
    transactions_plus_one =
      batch_number
      |> batch_transactions_fun.(@api_true)
      |> Enum.map(fn transaction -> transaction.transaction_hash end)
      |> Chain.hashes_to_transactions(full_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)
    next_page_params = next_page |> next_page_params(transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation :execution_node,
    summary: "List transactions executed on a specific execution node",
    description: "Retrieves transactions that were executed on the specified execution node.",
    parameters:
      [execution_node_hash_param() | base_params()] ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"List of transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 14_127_868,
             "index" => 0,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:execution_node_hash_param/execution-node` endpoint.
    It renders the list of transactions that were executed on the specified execution node.
  """
  @spec execution_node(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def execution_node(conn, %{execution_node_hash_param: execution_node_hash_string} = params) do
    with {:format, {:ok, execution_node_hash}} <- {:format, Chain.string_to_address_hash(execution_node_hash_string)} do
      full_options =
        [necessity_by_association: @transaction_necessity_by_association]
        |> Keyword.merge(put_key_value_to_paging_options(paging_options(params), :is_index_in_asc_order, true))
        |> Keyword.merge(@api_true)

      transactions_plus_one = Chain.execution_node_to_transactions(execution_node_hash, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(transactions, params)

      conn
      |> put_status(200)
      |> render(:transactions, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :raw_trace,
    summary: "Get step-by-step execution trace for a specific transaction",
    description:
      "Retrieves the raw execution trace for a transaction, showing the step-by-step execution path and all contract interactions.",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok: {"Raw execution trace for the specified transaction.", "application/json", Schemas.Transaction.RawTrace},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/raw-trace` endpoint.
  """
  @spec raw_trace(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def raw_trace(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      if is_nil(transaction.block_number) do
        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: []})
      else
        FirstTraceOnDemand.maybe_trigger_fetch(transaction, @api_true)

        case Chain.fetch_transaction_raw_traces(transaction) do
          {:ok, raw_traces} ->
            conn
            |> put_status(200)
            |> render(:raw_trace, %{raw_traces: raw_traces})

          {:error, error} ->
            Logger.error("Raw trace fetching failed: #{inspect(error)}")
            {500, "Error while raw trace fetching"}
        end
      end
    end
  end

  operation :token_transfers,
    summary: "List token transfers within a specific transaction",
    description:
      "Retrieves token transfers that occurred within a specific transaction, with optional filtering by token type.",
    parameters:
      base_params() ++
        [transaction_hash_param(), token_type_param()] ++
        define_paging_params([
          "index",
          "block_number",
          "batch_log_index",
          "batch_block_hash",
          "batch_transaction_hash",
          "index_in_batch"
        ]),
    responses: [
      ok:
        {"Token transfers within the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.TokenTransfer,
           next_page_params_example: %{
             "index" => 442,
             "block_number" => 21_307_214
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def token_transfers(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      paging_options = paging_options(params)

      full_options =
        [necessity_by_association: @token_transfers_necessity_by_association]
        |> Keyword.merge(paging_options)
        |> Keyword.merge(token_transfers_types_options(params))
        |> Keyword.merge(@api_true)
        |> fetch_scam_token_toggle(conn)

      results =
        transaction_hash
        |> Chain.transaction_to_token_transfers(full_options)
        |> Chain.flat_1155_batch_token_transfers()
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)

      conn
      |> put_status(200)
      |> render(:token_transfers, %{
        token_transfers:
          token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :internal_transactions,
    summary: "List internal transactions triggered during a specific transaction",
    description:
      "Retrieves internal transactions generated during the execution of a specific transaction. Useful for analyzing contract interactions and debugging failed transactions.",
    parameters:
      [transaction_hash_param() | base_params()] ++
        define_paging_params(["index", "block_number", "transaction_index", "items_count"]),
    responses: [
      ok:
        {"Internal transactions for the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.InternalTransaction,
           next_page_params_example: %{
             "index" => 50,
             "block_number" => 22_133_247,
             "transaction_index" => 68,
             "items_count" => 50
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def internal_transactions(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      internal_transactions_plus_one = transaction_to_internal_transactions(transaction, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(internal_transactions, params)

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :logs,
    summary: "List event logs emitted during a specific transaction",
    description:
      "Retrieves event logs emitted during the execution of a specific transaction. Logs contain information about contract events and state changes.",
    parameters:
      [transaction_hash_param() | base_params()] ++
        define_paging_params(["index", "block_number", "items_count"]),
    responses: [
      ok:
        {"Event logs for the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Log,
           next_page_params_example: %{
             "index" => 124,
             "block_number" => 21_925_703,
             "items_count" => 50
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/logs` endpoint.
  """
  @spec logs(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def logs(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        [
          necessity_by_association: %{
            [address: [:names, :smart_contract, proxy_implementations_smart_contracts_association()]] => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      logs_plus_one = Chain.transaction_to_logs(transaction_hash, full_options)

      {logs, next_page} = split_list_by_page(logs_plus_one)

      next_page_params =
        next_page
        |> next_page_params(logs, params)

      conn
      |> put_status(200)
      |> render(:logs, %{
        transaction_hash: transaction_hash,
        logs: logs |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :state_changes,
    summary: "Get on-chain state changes caused by a specific transaction",
    description: "Retrieves state changes (balance changes, token transfers) caused by a specific transaction.",
    parameters:
      [transaction_hash_param() | base_params()] ++ define_state_changes_paging_params(["state_changes", "items_count"]),
    responses: [
      ok: {
        "State changes caused by the specified transaction, with pagination.",
        "application/json",
        paginated_response(
          items: Schemas.Transaction.StateChange,
          next_page_params_example: %{
            "state_changes" => nil,
            "items_count" => 50
          }
        )
      },
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/state-changes` endpoint.
  """
  @spec state_changes(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def state_changes(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      state_changes_plus_next_page =
        transaction
        |> TransactionStateHelper.state_changes(
          params
          |> paging_options()
          |> Keyword.merge(@api_true)
          |> Keyword.put(:ip, AccessHelper.conn_to_ip_string(conn))
        )

      {state_changes, next_page} = split_list_by_page(state_changes_plus_next_page)

      next_page_params =
        next_page
        |> next_page_params(state_changes, params, true)

      conn
      |> put_status(200)
      |> render(:state_changes, %{state_changes: state_changes, next_page_params: next_page_params})
    end
  end

  operation :watchlist_transactions,
    summary: "List transactions in a user's watchlist",
    description: "Retrieves transactions in the authenticated user's watchlist.",
    parameters: base_params() ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Watchlist transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 23_617_990,
             "index" => 128,
             "items_count" => 50
           }
         )},
      forbidden: ForbiddenResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/watchlist` endpoint.
  """
  @spec watchlist_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:auth, any()}
  def watchlist_transactions(conn, params) do
    with {:auth, %{watchlist_id: watchlist_id}} <- {:auth, current_user(conn)} do
      full_options =
        [
          necessity_by_association: @transaction_necessity_by_association
        ]
        |> Keyword.merge(paging_options(params, [:validated]))
        |> Keyword.merge(@api_true)

      {watchlist_names, transactions_plus_one} = Chain.fetch_watchlist_transactions(watchlist_id, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params = next_page |> next_page_params(transactions, params)

      conn
      |> put_status(200)
      |> render(:transactions_watchlist, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params,
        watchlist_names: watchlist_names
      })
    end
  end

  operation :summary,
    summary: "Get a human-readable, LLM-based transaction summary",
    description: "Retrieves a human-readable summary of what a transaction did, presented in natural language.",
    parameters: base_params() ++ [transaction_hash_param(), just_request_body_param()],
    responses: [
      ok:
        {"Human-readable summary of the specified transaction.", "application/json",
         %Schema{
           anyOf: [
             Schemas.Transaction.Summary,
             Schemas.Transaction.SummaryJustRequestBody
           ]
         }},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/summary` endpoint.
  """
  @spec summary(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:transaction_interpreter_enabled, boolean}
          | Plug.Conn.t()
  def summary(conn, %{transaction_hash_param: transaction_hash_string, just_request_body: true} = params) do
    options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    with {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options) do
      conn
      |> json(TransactionInterpretationService.get_request_body(transaction))
    end
  end

  def summary(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    with {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options) do
      {response, code} =
        case TransactionInterpretationService.interpret(transaction) do
          {:ok, response} -> {response, 200}
          {:error, %Jason.DecodeError{}} -> {%{error: "Error while transaction interpreter response decoding"}, 500}
          {{:error, error}, code} -> {%{error: error}, code}
        end

      conn
      |> put_status(code)
      |> json(response)
    end
  end

  operation :blobs,
    summary: "List blobs for a transaction",
    description: "Retrieves blobs for a specific transaction (Ethereum only).",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok:
        {"Blobs for transaction.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             items: %Schema{type: :array, items: Schemas.Blob.Response}
           },
           nullable: false,
           additionalProperties: false
         }},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/blobs` endpoint.
  """
  @spec blobs(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def blobs(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options = @api_true

      blobs = BeaconReader.transaction_to_blobs(transaction_hash, full_options)

      conn
      |> put_status(200)
      |> put_view(BlobView)
      |> render(:blobs, %{blobs: blobs})
    end
  end

  operation :stats,
    summary: "Get transaction statistics",
    description: "Retrieves statistics for transactions, including counts and fee summaries for the last 24 hours.",
    responses: [
      ok:
        {"Transaction statistics.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             transactions_count_24h: Schemas.General.IntegerString,
             pending_transactions_count: Schemas.General.IntegerString,
             transaction_fees_sum_24h: Schemas.General.IntegerString,
             transaction_fees_avg_24h: Schemas.General.IntegerString
           },
           required: [
             :transactions_count_24h,
             :pending_transactions_count,
             :transaction_fees_sum_24h,
             :transaction_fees_avg_24h
           ],
           additionalProperties: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/transactions/stats` endpoint.
  """
  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, _params) do
    transactions_count = Transactions24hCount.fetch_count(@api_true)
    pending_transactions_count = NewPendingTransactionsCount.fetch(@api_true)
    transaction_fees_sum = Transactions24hCount.fetch_fee_sum(@api_true)
    transaction_fees_avg = Transactions24hCount.fetch_fee_average(@api_true)

    conn
    |> put_status(200)
    |> render(
      :stats,
      %{
        transactions_count_24h: transactions_count,
        pending_transactions_count: pending_transactions_count,
        transaction_fees_sum_24h: transaction_fees_sum,
        transaction_fees_avg_24h: transaction_fees_avg
      }
    )
  end

  operation :beacon_deposits,
    summary: "List beacon deposits in a transaction",
    description: "Retrieves beacon deposits included in a specific transaction with pagination support.",
    parameters: [transaction_hash_param() | base_params()] ++ define_paging_params(["index", "items_count"]),
    responses: [
      ok:
        {"Beacon deposits for transaction.", "application/json",
         paginated_response(
           items: Schemas.Beacon.Deposit.Response,
           next_page_params_example: %{
             "index" => 2_287_943,
             "items_count" => 50
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Handles `api/v2/transactions/:transaction_hash_param/beacon/deposits` endpoint.
  Fetches beacon deposits included in a specific transaction with pagination support.

  This endpoint retrieves all beacon deposits that were included in the
  specified transactions. The results include preloaded associations for both the from_address and
  withdrawal_address, including scam badges, names, smart contracts, and proxy
  implementations. The response is paginated and may include ENS and metadata
  enrichment if those services are enabled.

  ## Parameters
  - `conn`: The Plug connection.
  - `params`: A map containing:
    - `"transaction_hash_param"`: The transaction hash to fetch deposits from.
    - Optional pagination parameter:
      - `"index"`: non-negative integer, the starting index for pagination.

  ## Returns
  - `{:error, :not_found}` - If the transaction is not found.
  - `{:error, {:invalid, :hash}}` - If the transaction hash format is invalid.
  - `Plug.Conn.t()` - A 200 response with rendered deposits and pagination
    information when successful.
  """
  @spec beacon_deposits(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def beacon_deposits(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        [
          necessity_by_association: %{
            [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
            [withdrawal_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
              :optional
          },
          api?: true
        ]
        |> Keyword.merge(DepositController.paging_options(params))

      deposit_plus_one = BeaconDeposit.from_transaction_hash(transaction_hash, full_options)
      {deposits, next_page} = split_list_by_page(deposit_plus_one)

      next_page_params =
        next_page
        |> next_page_params(
          deposits,
          params,
          false,
          DepositController.paging_function()
        )

      conn
      |> put_status(200)
      |> put_view(DepositView)
      |> render(:deposits, %{
        deposits: deposits |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
  Checks if this valid transaction hash string, and this transaction doesn't belong to prohibited address
  """
  @spec validate_transaction(String.t(), any(), Keyword.t()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:ok, Transaction.t(), Hash.t()}
  def validate_transaction(transaction_hash_string, params, options \\ @api_true) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_full_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, options)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      {:ok, transaction, transaction_hash}
    end
  end
end
