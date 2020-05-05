defmodule BlockScoutWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.InternalTransactionView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash, [], false) do
      full_options =
        [
          necessity_by_association: %{
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      internal_transactions_plus_one = Chain.address_to_internal_transactions(address_hash, full_options)
      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_path =
        case next_page_params(next_page, internal_transactions, params) do
          nil ->
            nil

          next_page_params ->
            address_internal_transaction_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
        end

      internal_transactions_json =
        Enum.map(internal_transactions, fn internal_transaction ->
          View.render_to_string(
            InternalTransactionView,
            "_tile.html",
            current_address: address,
            internal_transaction: internal_transaction
          )
        end)

      json(conn, %{items: internal_transactions_json, next_page_path: next_page_path})
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        current_path: current_path(conn),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string})
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
