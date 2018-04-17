defmodule Explorer.ExchangeRates.Source.CoinMarketCap do
  @moduledoc """
  Adapter for fetching exchange rates from https://coinmarketcap.com.
  """

  alias Explorer.ExchangeRates.Rate
  alias Explorer.ExchangeRates.Source
  alias HTTPoison.Error
  alias HTTPoison.Response

  @behaviour Source

  @impl Source
  def fetch_exchange_rate(ticker) do
    url = source_url(ticker)
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, format_data(body)}

      {:ok, %Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc false
  def format_data(data) do
    [json] = decode_json(data)
    {last_updated_as_unix, _} = Integer.parse(json["last_updated"])
    last_updated = DateTime.from_unix!(last_updated_as_unix)

    %Rate{
      id: json["id"],
      last_updated: last_updated,
      name: json["name"],
      symbol: json["symbol"],
      usd_value: json["price_usd"]
    }
  end

  defp base_url do
    configured_url = Application.get_env(:explorer, __MODULE__, [])[:base_url]
    configured_url || "https://api.coinmarketcap.com"
  end

  defp decode_json(data) do
    :jiffy.decode(data, [:return_maps])
  end

  defp source_url(ticker) do
    "#{base_url()}/v1/ticker/#{ticker}/"
  end
end
