defmodule BlockScoutWeb.AddressTokenController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  alias BlockScoutWeb.AddressTokenView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
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
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = _params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      render(
        conn,
        "index.html",
        address: address,
        current_path: current_path(conn),
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        transaction_count: transaction_count(address),
        validation_count: validation_count(address)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
