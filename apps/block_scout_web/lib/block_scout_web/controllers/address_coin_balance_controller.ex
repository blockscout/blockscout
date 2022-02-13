defmodule BlockScoutWeb.AddressCoinBalanceController do
  @moduledoc """
  Manages the displaying of information about the coin balance history of an address
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressCoinBalanceView, Controller}
  alias BlockScoutWeb.Account.AuthController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, Wei}
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

      :not_found ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            json(conn, %{items: [], next_page_path: ""})

          _ ->
            not_found(conn)
        end

      :error ->
        unprocessable_entity(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      current_user = AuthController.current_user(conn)
      private_tags = AddressToTag.get_private_tags_on_address(address_hash, current_user)

      render(conn, "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: Controller.current_full_path(conn),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        private_tags: private_tags
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

        address = %Chain.Address{
          hash: address_hash,
          smart_contract: nil,
          token: nil,
          fetched_coin_balance: %Wei{value: Decimal.new(0)}
        }

        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            render(
              conn,
              "index.html",
              address: address,
              coin_balance_status: nil,
              exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
              counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
              current_path: Controller.current_full_path(conn)
            )

          _ ->
            not_found(conn)
        end

      :error ->
        unprocessable_entity(conn)
    end
  end
end
