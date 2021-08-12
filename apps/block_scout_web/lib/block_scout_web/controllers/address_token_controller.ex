defmodule BlockScoutWeb.AddressTokenController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressTokenView}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash, [], false),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      tokens_plus_one = Chain.address_tokens_with_balance(address_hash, paging_options(params))
      {tokens, next_page} = split_list_by_page(tokens_plus_one)

      next_page_path =
        case next_page_params(next_page, tokens, params) do
          nil ->
            nil

          next_page_params ->
            address_token_path(conn, :index, address, Map.delete(next_page_params, "type"))
        end

      items =
        tokens
        |> Market.add_price()
        |> Enum.map(fn token ->
          View.render_to_string(
            AddressTokenView,
            "_tokens.html",
            token: token,
            address: address,
            conn: conn
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
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

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        current_path: address_token_path(conn, :index, address_hash),
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)})
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
