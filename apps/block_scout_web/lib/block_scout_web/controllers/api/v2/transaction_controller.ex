defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  import BlockScoutWeb.Chain, only: [next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper, only: [paging_options: 2, filter_options: 1, method_filter_options: 1]

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @transaction_necessity_by_association %{
    :block => :optional,
    [created_contract_address: :names] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional
    # [to_address: :smart_contract] => :optional
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

  def transaction(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: @transaction_necessity_by_association
            )},
         preloaded <- Chain.preload_token_transfers(transaction, @token_transfers_neccessity_by_association) do
      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded})
    end
  end

  def transactions(conn, params) do
    filter_options = filter_options(params)
    method_filter_options = method_filter_options(params)

    full_options =
      Keyword.merge(
        [
          necessity_by_association: @transaction_necessity_by_association
        ],
        paging_options(params, filter_options)
      )

    transactions_plus_one = Chain.recent_transactions(full_options, filter_options, method_filter_options)
    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page_params(next_page, transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
  end
end
