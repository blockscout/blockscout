defmodule BlockScoutWeb.AddressCoinBalanceController do
  @moduledoc """
  Manages the displaying of information about the coin balance history of an address
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressCoinBalanceView, Controller}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Explorer.Tags.AddressToTag
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_address_exists(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      full_options = paging_options(params)

      coin_balances_plus_one = Chain.address_to_coin_balances(address_hash, full_options)

      {coin_balances, next_page} = split_list_by_page(coin_balances_plus_one)

      next_page_url =
        case next_page_params(next_page, coin_balances, params) do
          nil ->
            nil

          next_page_params ->
            address_coin_balance_path(
              conn,
              :index,
              address_hash,
              Map.delete(next_page_params, "type")
            )
        end

      coin_balances_json =
        Enum.map(coin_balances, fn coin_balance ->
          View.render_to_string(
            AddressCoinBalanceView,
            "_coin_balances.html",
            conn: conn,
            coin_balance: coin_balance
          )
        end)

      json(conn, %{items: coin_balances_json, next_page_path: next_page_url})
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      :not_found ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      tags = AddressToTag.get_tags_on_address(address_hash)

      render(conn, "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: Controller.current_full_path(conn),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        tags: tags
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
