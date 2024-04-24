defmodule Explorer.ExchangeRates.Source.Mobula do
  @moduledoc """
  Adapter for fetching exchange rates from https://mobula.io
  """

  alias Explorer.{Chain, Helper}
  alias Explorer.ExchangeRates.{Source, Token}

  import Source, only: [to_decimal: 1]

  @behaviour Source

  @impl Source
  def format_data(%{} = market_data_for_tokens) do

    market_data = market_data_for_tokens["data"]

    current_price = market_data["price"]
    image_url = market_data["logo"]

    id = String.downcase(market_data["symbol"])

    btc_value =
      if Application.get_env(:explorer, Explorer.ExchangeRates)[:fetch_btc_value], do: get_btc_value(id, market_data)

    circulating_supply_data = market_data && market_data["circulating_supply"]
    total_supply_data = market_data && market_data["total_supply"]
    market_cap_data_usd = market_data && market_data["market_cap"]
    total_volume_data_usd = market_data && market_data["volume"]

    [
      %Token{
        available_supply: to_decimal(circulating_supply_data),
        total_supply: to_decimal(total_supply_data) || to_decimal(circulating_supply_data),
        btc_value: btc_value,
        id: id,
        last_updated: nil,
        market_cap_usd: to_decimal(market_cap_data_usd),
        tvl_usd: nil,
        name: market_data["name"],
        symbol: String.upcase(market_data["symbol"]),
        usd_value: current_price,
        volume_24h_usd: to_decimal(total_volume_data_usd),
        image_url: image_url
      }
    ]
  end

  @impl Source
  def format_data(_), do: []

  @impl Source
  def source_url do
   "#{base_url()}/search?input=#{coin_id()}"
  end

  @impl Source
  def source_url(token_addresses) when is_list(token_addresses) do
    joined_addresses = token_addresses |> Enum.map_join(",", &to_string/1)

    "#{base_url()}/market/multi-data?blockchains=#{chain()}&assets=#{joined_addresses}"
  end

  @impl Source
  def headers do
    if api_key() do
      [{"Authorization", "#{api_key()}"}]
    else
      []
    end
  end

  @doc """
  Converts date time string into DateTime object formatted as date
  """
  @spec date(String.t()) :: Date.t()
  def date(date_time_string) do
    with {:ok, datetime, _} <- DateTime.from_iso8601(date_time_string) do
      datetime
      |> DateTime.to_date()
    end
  end

  defp api_key do
    config(:api_key) || nil
  end

  def coin_id do
    symbol = String.downcase(Explorer.coin())
  end

  defp get_current_price(market_data) do
    if market_data["price"] do
      to_decimal(market_data["price"])
    else
      1
    end
  end

  defp get_btc_value(id, market_data) do
    case get_btc_price() do
      {:ok, price} ->
        btc_price = to_decimal(price)
        current_price = get_current_price(market_data)

        if id != "btc" && current_price && btc_price do
          Decimal.div(current_price, btc_price)
        else
          1
        end

      _ ->
        1
    end
  end

  defp chain do
    config(:platform) || "ethereum"
  end

  defp base_url do
     config(:base_url) || "https://api.mobula.io/api/1"
  end

  defp get_btc_price() do
    url = "#{base_url()}/market/data?asset=Bitcoin"

    case Source.http_request(url, headers()) do
      {:ok, data} = resp ->
        if is_map(data) do
          current_price = data['price']

          {:ok, current_price}
        else
          resp
        end

      resp ->
        resp
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
