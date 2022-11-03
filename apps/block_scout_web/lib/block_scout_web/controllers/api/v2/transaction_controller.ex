defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper,
    only: [paging_options: 2, filter_options: 1, method_filter_options: 1, type_filter_options: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Runner.InternalTransactions

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

  def transaction(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: @transaction_necessity_by_association
            )},
         preloaded <- Chain.preload_token_transfers(transaction, @token_transfers_neccessity_by_association, false) do
      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded})
    end
  end

  def transactions(conn, params) do
    filter_options = filter_options(params)
    method_filter_options = method_filter_options(params)
    type_filter_options = type_filter_options(params)

    full_options =
      Keyword.merge(
        [
          necessity_by_association: @transaction_necessity_by_association
        ],
        paging_options(params, filter_options)
      )

    transactions_plus_one =
      Chain.recent_transactions(full_options, filter_options, method_filter_options, type_filter_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page_params(next_page, transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
  end

  def raw_trace(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash)} do
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

        json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

        internal_transactions =
          if first_trace_exists do
            internal_transactions
          else
            response =
              Chain.fetch_first_trace(
                [
                  %{
                    block_hash: transaction.block_hash,
                    block_number: transaction.block_number,
                    hash_data: transaction_hash_string,
                    transaction_index: transaction.index
                  }
                ],
                json_rpc_named_arguments
              )

            case response do
              {:ok, first_trace_params} ->
                InternalTransactions.run_insert_only(first_trace_params, %{
                  timeout: :infinity,
                  timestamps: Import.timestamps(),
                  internal_transactions: %{params: first_trace_params}
                })

                Chain.all_transaction_to_internal_transactions(transaction_hash)

              {:error, _} ->
                internal_transactions

              :ignore ->
                internal_transactions
            end
          end

        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: internal_transactions})
      end
    end
  end

  def token_transfers(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)} do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: @token_transfers_neccessity_by_association
          ],
          paging_options(params)
        )

      token_transfers_plus_one = Chain.transaction_to_token_transfers(transaction_hash, full_options)

      {token_transfers, next_page} = split_list_by_page(token_transfers_plus_one)

      next_page_params = next_page_params(next_page, token_transfers, params)

      conn
      |> put_status(200)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def internal_transactions(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)} do
      full_options =
        Keyword.merge(
          @internal_transaction_neccessity_by_association,
          paging_options(params)
        )

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params = next_page_params(next_page, internal_transactions, params)

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      })
    end
  end

  def logs(conn, %{"transaction_hash" => transaction_hash_string} = params) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)} do
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

      next_page_params = next_page_params(next_page, logs, params)

      conn
      |> put_status(200)
      |> render(:logs, %{
        tx_hash: transaction_hash,
        logs: logs,
        next_page_params: next_page_params
      })
    end
  end
end
