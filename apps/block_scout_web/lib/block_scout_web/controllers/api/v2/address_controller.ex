defmodule BlockScoutWeb.API.V2.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      current_filter: 1
    ]

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.{Chain, Market}
  alias Indexer.Fetcher.TokenBalanceOnDemand

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      :block => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  @transaction_with_tt_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional,
      :block => :required
    }
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def address(conn, %{"address_hash" => address_hash_string}) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:not_found, {:ok, address}} <- {:not_found, Chain.hash_to_address(address_hash)} do
      conn
      |> put_status(200)
      |> render(:address, %{address: address})
    end
  end

  def token_balances(conn, %{"address_hash" => address_hash_string}) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)} do
      token_balances =
        address_hash
        |> Chain.fetch_last_token_balances()

      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash, token_balances)
      end)

      token_balances_with_price =
        token_balances
        |> Market.add_price()

      conn
      |> put_status(200)
      |> render(:token_balances, %{token_balances: token_balances_with_price})
    end
  end

  def transactions(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)} do
      options =
        @transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      results_plus_one = Chain.address_to_transactions_with_rewards(address_hash, options)
      {transactions, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page_params(next_page, transactions, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
    end
  end

  def token_transfers(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)} do
      options =
        @transaction_with_tt_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      results_plus_one =
        Chain.address_hash_to_token_transfers(
          address_hash,
          options
        )

      {transactions, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page_params(next_page, transactions, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
    end
  end
end
