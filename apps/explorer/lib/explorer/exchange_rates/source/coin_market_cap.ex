defmodule Explorer.ExchangeRates.Source.CoinMarketCap do
  @moduledoc """
  Adapter for fetching exchange rates from https://coinmarketcap.com/api/
  """

  alias Explorer.Chain
  alias Explorer.ExchangeRates.{Source, Token}

  import Source, only: [to_decimal: 1]

  @behaviour Source

  @impl Source
  def format_data(%{"data" => _} = json_data) do
    market_data = json_data["data"]
    token_properties = get_token_properties(market_data)

    last_updated = get_last_updated(token_properties)
    current_price = get_current_price(token_properties)

    id = token_properties["id"]

    btc_value =
      if Application.get_env(:explorer, Explorer.ExchangeRates)[:fetch_btc_value],
        do: get_btc_value(id, token_properties)

    circulating_supply_data = get_circulating_supply(token_properties)

    total_supply_data = get_total_supply(token_properties)

    market_cap_data_usd = get_market_cap_data_usd(token_properties)

    total_volume_data_usd = get_total_volume_data_usd(token_properties)

    [
      %Token{
        available_supply: to_decimal(circulating_supply_data),
        total_supply: to_decimal(total_supply_data) || to_decimal(circulating_supply_data),
        btc_value: btc_value,
        id: id,
        last_updated: last_updated,
        market_cap_usd: to_decimal(market_cap_data_usd),
        name: token_properties["name"],
        symbol: String.upcase(token_properties["symbol"]),
        usd_value: current_price,
        volume_24h_usd: to_decimal(total_volume_data_usd)
      }
    ]
  end

  @impl Source
  def format_data(_), do: []

  @impl Source
  def source_url do
    coin = Explorer.coin()
    symbol = if coin, do: String.upcase(Explorer.coin()), else: nil
    coin_id = coin_id()

    cond do
      coin_id ->
        "#{api_quotes_latest_url()}?id=#{coin_id}&CMC_PRO_API_KEY=#{api_key()}"

      symbol ->
        "#{api_quotes_latest_url()}?symbol=#{symbol}&CMC_PRO_API_KEY=#{api_key()}"

      true ->
        nil
    end
  end

  @impl Source
  def source_url(input) do
    case Chain.Hash.Address.cast(input) do
      {:ok, _} ->
        # todo: find symbol by contract address hash
        nil

      _ ->
        symbol = if input, do: input |> String.upcase(), else: nil

        if symbol,
          do: "#{api_quotes_latest_url()}?symbol=#{symbol}&CMC_PRO_API_KEY=#{api_key()}",
          else: nil
    end
  end

  @impl Source
  def headers do
    []
  end

  defp api_key do
    config(:api_key)
  end

  defp coin_id do
    config(:coin_id)
  end

  @doc """
  Extracts token properties from CoinMarketCap coin endpoint response
  """
  @spec get_token_properties(map()) :: map()
  def get_token_properties(market_data) do
    with token_values_list <- market_data |> Map.values(),
         true <- Enum.count(token_values_list) > 0,
         token_values <- token_values_list |> Enum.at(0),
         true <- Enum.count(token_values) > 0 do
      token_values |> Enum.at(0)
    else
      _ -> %{}
    end
  end

  defp get_circulating_supply(token_properties) do
    token_properties["circulating_supply"]
  end

  defp get_total_supply(token_properties) do
    token_properties["total_supply"]
  end

  @doc """
  Extracts market cap in usd from token properties, which are returned in get_token_properties/1
  """
  @spec get_market_cap_data_usd(map()) :: String.t()
  def get_market_cap_data_usd(token_properties) do
    token_properties["quote"] &&
      token_properties["quote"]["USD"] &&
      token_properties["quote"]["USD"]["market_cap"]
  end

  defp get_total_volume_data_usd(token_properties) do
    token_properties["quote"] &&
      token_properties["quote"]["USD"] &&
      token_properties["quote"]["USD"]["volume_24h"]
  end

  @doc """
  Extracts last updated from token properties, which are returned in get_token_properties/1
  """
  @spec get_last_updated(map()) :: DateTime.t()
  def get_last_updated(token_properties) do
    last_updated_data = token_properties && token_properties["last_updated"]

    if last_updated_data do
      {:ok, last_updated, 0} = DateTime.from_iso8601(last_updated_data)
      last_updated
    else
      nil
    end
  end

  @doc """
  Extracts current price from token properties, which are returned in get_token_properties/1
  """
  @spec get_current_price(map()) :: String.t() | non_neg_integer()
  def get_current_price(token_properties) do
    if token_properties["quote"] && token_properties["quote"]["USD"] &&
         token_properties["quote"]["USD"]["price"] do
      to_decimal(token_properties["quote"]["USD"]["price"])
    else
      1
    end
  end

  defp get_btc_value(id, token_properties) do
    case get_btc_price() do
      {:ok, price} ->
        btc_price = to_decimal(price)
        current_price = get_current_price(token_properties)

        if id != "btc" && current_price && btc_price do
          Decimal.div(current_price, btc_price)
        else
          1
        end

      _ ->
        1
    end
  end

  defp base_url do
    config(:base_url) || "https://pro-api.coinmarketcap.com/v2"
  end

  defp api_quotes_latest_url do
    "#{base_url()}/cryptocurrency/quotes/latest"
  end

  defp get_btc_price(currency \\ "usd") do
    url = "#{api_quotes_latest_url()}?symbol=BTC&CMC_PRO_API_KEY=#{api_key()}"

    case Source.http_request(url, headers()) do
      {:ok, data} = resp ->
        if is_map(data) do
          current_price = data["rates"][currency]["value"]

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
