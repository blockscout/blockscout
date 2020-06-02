defmodule BlockScoutWeb.AddressCoinBalanceController do
  @moduledoc """
  Manages the displaying of information about the coin balance history of an address
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.AddressCoinBalanceView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_address_exists(address_hash) do
      full_options = paging_options(params)

      coin_balances_plus_one = Chain.address_to_coin_balances(address_hash, full_options)

      {coin_balances, next_page} = split_list_by_page(coin_balances_plus_one)

      deduplicated_coin_balances =
        coin_balances
        |> Enum.dedup_by(fn record ->
          if record.delta == Decimal.new(0) do
            :dup
          else
            System.unique_integer()
          end
        end)

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
        Enum.map(deduplicated_coin_balances, fn coin_balance ->
          View.render_to_string(
            AddressCoinBalanceView,
            "_coin_balances.html",
            conn: conn,
            coin_balance: coin_balance
          )
        end)

      json(conn, %{items: coin_balances_json, next_page_path: next_page_url})
    else
      :error ->
        unprocessable_entity(conn)

      :not_found ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      render(conn, "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: current_path(conn),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)})
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
