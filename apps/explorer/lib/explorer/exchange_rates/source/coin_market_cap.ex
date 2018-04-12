defmodule Explorer.ExchangeRates.Source.CoinMarketCap do
  @moduledoc """
  Adapter for fetching exchange rates from https://coinmarketcap.com.
  """

  alias Explorer.ExchangeRates.Rate
  alias Explorer.ExchangeRates.Source

  @behaviour Source

  @impl Source
  def fetch_exchange_rate(ticker) do
    url = "https://api.coinmarketcap.com/v1/ticker/#{ticker}/"
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        {:ok, format_data(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc false
  def format_data(data) do
    [json] = decode_json(data)
    {last_updated_as_unix, _} = Integer.parse(json["last_updated"])
    last_updated = DateTime.from_unix!(last_updated_as_unix)

    %Rate{
      last_updated: last_updated,
      ticker_name: json["name"],
      ticker_symbol: json["symbol"],
      ticker: json["id"],
      usd_value: json["price_usd"]
    }
  end

  defp decode_json(data) do
    :jiffy.decode(data, [:return_maps])
  end
end
