defmodule Explorer.ExchangeRates.Source.CoinMarketCap do
  @moduledoc """
  Adapter for fetching exchange rates from https://coinmarketcap.com.
  """

  alias Explorer.ExchangeRates.{Source, Token}
  alias HTTPoison.{Error, Response}

  import Source, only: [decode_json: 1, to_decimal: 1, headers: 0]

  @behaviour Source

  @impl Source
  def fetch_exchange_rates do
    case HTTPoison.get(source_url(), headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, format_data(body)}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc false
  def format_data(data) do
    for item <- decode_json(data), not is_nil(item["last_updated"]) do
      {last_updated_as_unix, _} = Integer.parse(item["last_updated"])
      last_updated = DateTime.from_unix!(last_updated_as_unix)

      %Token{
        available_supply: to_decimal(item["available_supply"]),
        btc_value: to_decimal(item["price_btc"]),
        id: item["id"],
        last_updated: last_updated,
        market_cap_usd: to_decimal(item["market_cap_usd"]),
        name: item["name"],
        symbol: item["symbol"],
        usd_value: to_decimal(item["price_usd"]),
        volume_24h_usd: to_decimal(item["24h_volume_usd"])
      }
    end
  end

  defp base_url do
    configured_url = Application.get_env(:explorer, __MODULE__, [])[:base_url]
    configured_url || "https://api.coinmarketcap.com"
  end

  defp source_url do
    "#{base_url()}/v1/ticker/?limit=0"
  end
end
