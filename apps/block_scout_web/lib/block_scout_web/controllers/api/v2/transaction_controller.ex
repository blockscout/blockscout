defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      paging_options: 2,
      filter_options: 2,
      method_filter_options: 1,
      token_transfers_types_options: 1,
      type_filter_options: 1
    ]

  alias BlockScoutWeb.AccessHelpers
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
    [to_address: :smart_contract] => :optional
  }

  @token_transfers_neccessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    from_address: :required,
    to_address: :required
  }

  @token_transfers_in_tx_neccessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    from_address: :required,
    to_address: :required,
    token: :required
  }

  @internal_transaction_neccessity_by_association [
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

  def transaction(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: Map.put(@transaction_necessity_by_association, :transaction_actions, :optional)
            )},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params),
         preloaded <-
           Chain.preload_token_transfers(transaction, @token_transfers_in_tx_neccessity_by_association, false) do
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
           {:not_found, Chain.hash_to_transaction(transaction_hash)},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      if is_nil(transaction.block_number) do
        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: []})
      else
        internal_transactions = Chain.all_transaction_to_internal_transactions(transaction_hash)

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
           {:not_found, Chain.hash_to_transaction(transaction_hash)},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        [necessity_by_association: @token_transfers_neccessity_by_association]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(token_transfers_types_options(params))

      token_transfers_plus_one = Chain.transaction_to_token_transfers(transaction_hash, full_options)

      {token_transfers, next_page} = split_list_by_page(token_transfers_plus_one)

      next_page_params =
        next_page
        |> next_page_params(token_transfers, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def internal_transactions(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash)},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        Keyword.merge(
          @internal_transaction_neccessity_by_association,
          paging_options(params)
        )

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
           {:not_found, Chain.hash_to_transaction(transaction_hash)},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              [address: :names] => :optional,
              [address: :smart_contract] => :optional,
              address: :optional
            }
          ],
          paging_options(params)
        )

      from_api = true
      logs_plus_one = Chain.transaction_to_logs(transaction_hash, from_api, full_options)

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
                Map.merge(@transaction_necessity_by_association, %{[block: [miner: :names]] => :optional})
            )},
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      state_changes = TransactionStateHelper.state_changes(transaction)

      conn
      |> put_status(200)
      |> render(:state_changes, %{state_changes: state_changes})
    end
  end
end
