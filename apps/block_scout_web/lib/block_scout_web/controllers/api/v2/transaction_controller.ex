defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  alias BlockScoutWeb.API.V2.BlobView

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      put_key_value_to_paging_options: 3,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      fetch_scam_token_toggle: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      paging_options: 2,
      filter_options: 2,
      method_filter_options: 1,
      token_transfers_types_options: 1,
      type_filter_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1, maybe_preload_ens_to_transaction: 1]

  import Explorer.MicroserviceInterfaces.Metadata,
    only: [maybe_preload_metadata: 1, maybe_preload_metadata_to_transaction: 1]

  import Ecto.Query,
    only: [
      preload: 2
    ]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation, as: TransactionInterpretationService
  alias BlockScoutWeb.Models.TransactionStateHelper
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.Arbitrum.Reader.API.Settlement, as: ArbitrumSettlementReader
  alias Explorer.Chain.Beacon.Reader, as: BeaconReader
  alias Explorer.Chain.Cache.Counters.{NewPendingTransactionsCount, Transactions24hCount}
  alias Explorer.Chain.{Hash, InternalTransaction, Transaction}
  alias Explorer.Chain.Optimism.TransactionBatch, as: OptimismTransactionBatch
  alias Explorer.Chain.PolygonZkevm.Reader, as: PolygonZkevmReader
  alias Explorer.Chain.Scroll.Reader, as: ScrollReader
  alias Explorer.Chain.Token.Instance
  alias Explorer.Chain.ZkSync.Reader, as: ZkSyncReader
  alias Indexer.Fetcher.OnDemand.FirstTrace, as: FirstTraceOnDemand
  alias Indexer.Fetcher.OnDemand.NeonSolanaTransactions, as: NeonSolanaTransactions

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  case @chain_type do
    :ethereum ->
      @chain_type_transaction_necessity_by_association %{
        :beacon_blob_transaction => :optional
      }

    :celo ->
      @chain_type_transaction_necessity_by_association %{
        :gas_token => :optional
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
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
  }

  @token_transfers_in_transaction_necessity_by_association %{
    [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    token: :required
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

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param` endpoint.
  """
  @spec transaction(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def transaction(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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

    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/zkevm-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec polygon_zkevm_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def polygon_zkevm_batch(conn, %{"batch_number" => batch_number} = _params) do
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

  @doc """
    Function to handle GET requests to `/api/v2/transactions/zksync-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec zksync_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zksync_batch(conn, params) do
    handle_batch_transactions(conn, params, &ZkSyncReader.batch_transactions/2)
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/arbitrum-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec arbitrum_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def arbitrum_batch(conn, params) do
    handle_batch_transactions(conn, params, &ArbitrumSettlementReader.batch_transactions/2)
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:tx_hash/external-transactions` endpoint.
    It renders the list of external transactions that are somehow linked (eg. preceded or initiated by) to the selected one.
    The most common use case is for side-chains and rollups. Currently implemented only for Neon chain but could also be extended for
    similar cases.
  """
  @spec external_transactions(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def external_transactions(conn, %{"transaction_hash_param" => transaction_hash} = _params) do
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

  @doc """
    Function to handle GET requests to `/api/v2/transactions/optimism-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec optimism_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def optimism_batch(conn, %{"batch_number" => batch_number_string} = params) do
    {batch_number, ""} = Integer.parse(batch_number_string)

    l2_block_number_from = OptimismTransactionBatch.edge_l2_block_number(batch_number, :min)
    l2_block_number_to = OptimismTransactionBatch.edge_l2_block_number(batch_number, :max)

    handle_block_range_transactions(conn, params, l2_block_number_from, l2_block_number_to)
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/scroll-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec scroll_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def scroll_batch(conn, %{"batch_number" => batch_number_string} = params) do
    {batch_number, ""} = Integer.parse(batch_number_string)

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
    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

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
  defp handle_batch_transactions(conn, %{"batch_number" => batch_number} = params, batch_transactions_fun) do
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
    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  def execution_node(conn, %{"execution_node_hash_param" => execution_node_hash_string} = params) do
    with {:format, {:ok, execution_node_hash}} <- {:format, Chain.string_to_address_hash(execution_node_hash_string)} do
      full_options =
        [necessity_by_association: @transaction_necessity_by_association]
        |> Keyword.merge(put_key_value_to_paging_options(paging_options(params), :is_index_in_asc_order, true))
        |> Keyword.merge(@api_true)

      transactions_plus_one = Chain.execution_node_to_transactions(execution_node_hash, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:transactions, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/raw-trace` endpoint.
  """
  @spec raw_trace(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def raw_trace(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def token_transfers(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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
        |> token_transfers_next_page_params(token_transfers, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:token_transfers, %{
        token_transfers:
          token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def internal_transactions(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      internal_transactions_plus_one =
        InternalTransaction.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(internal_transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/logs` endpoint.
  """
  @spec logs(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def logs(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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
        |> next_page_params(logs, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:logs, %{
        transaction_hash: transaction_hash,
        logs: logs |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/state-changes` endpoint.
  """
  @spec state_changes(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def state_changes(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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
        |> next_page_params(state_changes, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:state_changes, %{state_changes: state_changes, next_page_params: next_page_params})
    end
  end

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

      next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:transactions_watchlist, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params,
        watchlist_names: watchlist_names
      })
    end
  end

  def summary(conn, %{"transaction_hash_param" => transaction_hash_string, "just_request_body" => "true"} = params) do
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

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/summary` endpoint.
  """
  @spec summary(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:transaction_interpreter_enabled, boolean}
          | Plug.Conn.t()
  def summary(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
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

  @doc """
  Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/blobs` endpoint.
  """
  @spec blobs(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def blobs(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options = @api_true

      blobs = BeaconReader.transaction_to_blobs(transaction_hash, full_options)

      conn
      |> put_status(200)
      |> put_view(BlobView)
      |> render(:blobs, %{blobs: blobs})
    end
  end

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
