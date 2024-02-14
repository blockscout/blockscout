defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  alias BlockScoutWeb.API.V2.BlobView

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      put_key_value_to_paging_options: 3,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
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

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation, as: TransactionInterpretationService
  alias BlockScoutWeb.Models.TransactionStateHelper
  alias Explorer.Chain
  alias Explorer.Chain.Beacon.Reader, as: BeaconReader
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Zkevm.Reader
  alias Indexer.Fetcher.FirstTraceOnDemand

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  case Application.compile_env(:explorer, :chain_type) do
    "ethereum" ->
      @chain_type_transaction_necessity_by_association %{
        :beacon_blob_transaction => :optional
      }

    _ ->
      @chain_type_transaction_necessity_by_association %{}
  end

  # TODO might be redundant to preload blob fields in some of the endpoints
  @transaction_necessity_by_association %{
                                          :block => :optional,
                                          [created_contract_address: :names] => :optional,
                                          [created_contract_address: :token] => :optional,
                                          [from_address: :names] => :optional,
                                          [to_address: :names] => :optional,
                                          [to_address: :smart_contract] => :optional
                                        }
                                        |> Map.merge(@chain_type_transaction_necessity_by_association)

  @token_transfers_necessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional
  }

  @token_transfers_in_tx_necessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    token: :required
  }

  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param` endpoint.
  """
  @spec transaction(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def transaction(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    necessity_by_association_with_actions =
      Map.put(@transaction_necessity_by_association, :transaction_actions, :optional)

    necessity_by_association =
      case Application.get_env(:explorer, :chain_type) do
        "polygon_zkevm" ->
          necessity_by_association_with_actions
          |> Map.put(:zkevm_batch, :optional)
          |> Map.put(:zkevm_sequence_transaction, :optional)
          |> Map.put(:zkevm_verify_transaction, :optional)

        "suave" ->
          necessity_by_association_with_actions
          |> Map.put(:logs, :optional)
          |> Map.put([execution_node: :names], :optional)
          |> Map.put([wrapped_to_address: :names], :optional)

        _ ->
          necessity_by_association_with_actions
      end

    with {:ok, transaction, _transaction_hash} <-
           validate_transaction(transaction_hash_string, params,
             necessity_by_association: necessity_by_association,
             api?: true
           ),
         preloaded <-
           Chain.preload_token_transfers(transaction, @token_transfers_in_tx_necessity_by_association, @api_true, false) do
      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded |> maybe_preload_ens_to_transaction()})
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
    |> render(:transactions, %{transactions: transactions |> maybe_preload_ens(), next_page_params: next_page_params})
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/zkevm-batch/:batch_number` endpoint.
    It renders the list of L2 transactions bound to the specified batch.
  """
  @spec zkevm_batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zkevm_batch(conn, %{"batch_number" => batch_number} = _params) do
    transactions =
      batch_number
      |> Reader.batch_transactions(api?: true)
      |> Enum.map(fn tx -> tx.hash end)
      |> Chain.hashes_to_transactions(api?: true, necessity_by_association: @transaction_necessity_by_association)

    conn
    |> put_status(200)
    |> render(:transactions, %{transactions: transactions |> maybe_preload_ens(), items: true})
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
      |> render(:transactions, %{transactions: transactions |> maybe_preload_ens(), next_page_params: next_page_params})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/raw-trace` endpoint.
  """
  @spec raw_trace(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def raw_trace(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:ok, transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      if is_nil(transaction.block_number) do
        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: []})
      else
        internal_transactions = Chain.all_transaction_to_internal_transactions(transaction_hash, @api_true)

        first_trace_exists =
          Enum.find_index(internal_transactions, fn trace ->
            trace.index == 0
          end)

        if !first_trace_exists do
          FirstTraceOnDemand.trigger_fetch(transaction)
        end

        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: internal_transactions})
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
        token_transfers: token_transfers |> maybe_preload_ens(),
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

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(internal_transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions |> maybe_preload_ens(),
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
            [address: :names] => :optional,
            [address: :smart_contract] => :optional,
            address: :optional
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
        tx_hash: transaction_hash,
        logs: logs |> maybe_preload_ens(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/state-changes` endpoint.
  """
  @spec state_changes(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def state_changes(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <-
           validate_transaction(transaction_hash_string, params,
             necessity_by_association:
               Map.merge(@transaction_necessity_by_association, %{[block: [miner: :names]] => :optional}),
             api?: true
           ) do
      state_changes_plus_next_page =
        transaction |> TransactionStateHelper.state_changes(params |> paging_options() |> Keyword.merge(api?: true))

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
        transactions: transactions |> maybe_preload_ens(),
        next_page_params: next_page_params,
        watchlist_names: watchlist_names
      })
    end
  end

  def summary(conn, %{"transaction_hash_param" => transaction_hash_string, "just_request_body" => "true"} = params) do
    with {:tx_interpreter_enabled, true} <- {:tx_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
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
          | {:tx_interpreter_enabled, boolean}
          | Plug.Conn.t()
  def summary(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:tx_interpreter_enabled, true} <- {:tx_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      {response, code} =
        case TransactionInterpretationService.interpret(transaction) do
          {:ok, response} -> {response, 200}
          {:error, %Jason.DecodeError{}} -> {%{error: "Error while tx interpreter response decoding"}, 500}
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

  @doc """
  Checks if this valid transaction hash string, and this transaction doesn't belong to prohibited address
  """
  @spec validate_transaction(String.t(), any(), Keyword.t()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:ok, Transaction.t(), Hash.t()}
  def validate_transaction(transaction_hash_string, params, options \\ @api_true) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, options)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      {:ok, transaction, transaction_hash}
    end
  end
end
