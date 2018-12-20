defmodule Explorer.ExchangeRates.Source.CoinGecko do
  @moduledoc """
  Adapter for fetching exchange rates from https://coingecko.com
  """

  alias Explorer.ExchangeRates.{Source, Token}
  alias HTTPoison.{Error, Response}

  import Source, only: [decode_json: 1, to_decimal: 1, headers: 0]

  @behaviour Source

  @impl Source
  def format_data(data) do
    {:ok, price} = get_btc_price()
    btc_price = to_decimal(price)

    for item <- decode_json(data),
        not is_nil(item["total_supply"]) and not is_nil(item["current_price"]) do
      {:ok, last_updated, 0} = DateTime.from_iso8601(item["last_updated"])

      current_price = to_decimal(item["current_price"])

      id = item["id"]
      btc_value = if id != "btc", do: Decimal.div(current_price, btc_price), else: 1

      %Token{
        available_supply: to_decimal(item["total_supply"]),
        btc_value: btc_value,
        id: id,
        last_updated: last_updated,
        market_cap_usd: to_decimal(item["market_cap"]),
        name: item["name"],
        symbol: item["symbol"],
        usd_value: current_price,
        volume_24h_usd: to_decimal(item["total_volume"])
      }
    end
  end

  @impl Source
  def source_url(currency \\ "usd") do
    "#{base_url()}/coins/markets?vs_currency=#{currency}"
  end

  defp base_url do
    config(:base_url) || "https://api.coingecko.com/api/v3"
  end

  defp get_btc_price(currency \\ "usd") do
    url = "#{base_url()}/exchange_rates"

    case HTTPoison.get(url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        data = decode_json(body)
        current_price = data["rates"][currency]["value"]

        {:ok, current_price}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
