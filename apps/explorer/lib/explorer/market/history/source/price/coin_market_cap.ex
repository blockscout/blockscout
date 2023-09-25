defmodule Explorer.Market.History.Source.Price.CoinMarketCap do
  @moduledoc """
  Adapter for fetching current market from CoinMarketCap.
  """

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.CoinMarketCap, as: ExchangeRatesSourceCoinMarketCap
  alias Explorer.Market.History.Source.Price, as: SourcePrice

  @behaviour SourcePrice

  @impl SourcePrice
  def fetch_price_history(_previous_days \\ nil) do
    url = ExchangeRatesSourceCoinMarketCap.source_url()

    if url do
      case Source.http_request(url, ExchangeRatesSourceCoinMarketCap.headers()) do
        {:ok, data} ->
          result =
            data
            |> format_data()

          {:ok, result}

        _ ->
          :error
      end
    else
      :error
    end
  end

  @spec format_data(term()) :: SourcePrice.record() | nil
  defp format_data(nil), do: nil

  defp format_data(%{"data" => _} = json_data) do
    market_data = json_data["data"]
    token_properties = ExchangeRatesSourceCoinMarketCap.get_token_properties(market_data)

    last_updated =
      token_properties
      |> ExchangeRatesSourceCoinMarketCap.get_last_updated()
      |> DateTime.to_date()

    current_price_usd = ExchangeRatesSourceCoinMarketCap.get_current_price(token_properties)

    [
      %{
        closing_price: current_price_usd,
        date: last_updated,
        opening_price: current_price_usd
      }
    ]
  end
end
