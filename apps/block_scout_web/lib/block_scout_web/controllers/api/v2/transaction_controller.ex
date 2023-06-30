defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain,
    only: [next_page_params: 3, token_transfers_next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      paging_options: 2,
      filter_options: 2,
      method_filter_options: 1,
      token_transfers_types_options: 1,
      type_filter_options: 1
    ]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Models.TransactionStateHelper
  alias Explorer.Chain
  alias Indexer.Fetcher.FirstTraceOnDemand

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @transaction_necessity_by_association %{
    :block => :optional,
    [created_contract_address: :names] => :optional,
    [created_contract_address: :token] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    # as far as I remember this needed for substituting implementation name in `to` address instead of is's real name (in transactions)
    [to_address: :smart_contract] => :optional
  }

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
      [transaction: :block] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  @api_true [api?: true]

  def transaction(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: Map.put(@transaction_necessity_by_association, :transaction_actions, :optional),
              api?: true
            )},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params),
         preloaded <-
           Chain.preload_token_transfers(transaction, @token_transfers_in_tx_necessity_by_association, @api_true, false) do
      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded})
    end
  end

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

    next_page_params = next_page |> next_page_params(transactions, params) |> delete_parameters_from_next_page_params()

    conn
    |> put_status(200)
    |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
  end

  def raw_trace(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, @api_true)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
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

  def token_transfers(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, @api_true)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
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
        |> token_transfers_next_page_params(token_transfers, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def internal_transactions(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, @api_true)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(internal_transactions, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      })
    end
  end

  def logs(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, @api_true)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
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
        |> next_page_params(logs, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:logs, %{
        tx_hash: transaction_hash,
        logs: logs,
        next_page_params: next_page_params
      })
    end
  end

  def state_changes(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(transaction_hash,
              necessity_by_association:
                Map.merge(@transaction_necessity_by_association, %{[block: [miner: :names]] => :optional}),
              api?: true
            )},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      state_changes_plus_next_page =
        transaction |> TransactionStateHelper.state_changes(params |> paging_options() |> Keyword.merge(api?: true))

      {state_changes, next_page} = split_list_by_page(state_changes_plus_next_page)

      next_page_params =
        next_page
        |> next_page_params(state_changes, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:state_changes, %{state_changes: state_changes, next_page_params: next_page_params})
    end
  end

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

      next_page_params =
        next_page |> next_page_params(transactions, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:transactions_watchlist, %{
        transactions: transactions,
        next_page_params: next_page_params,
        watchlist_names: watchlist_names
      })
    end
  end
end
