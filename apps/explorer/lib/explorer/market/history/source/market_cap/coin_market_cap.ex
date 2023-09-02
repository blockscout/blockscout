defmodule Explorer.Market.History.Source.MarketCap.CoinMarketCap do
  @moduledoc """
  Adapter for fetching current market from CoinMarketCap.
  """

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.CoinMarketCap, as: ExchangeRatesSourceCoinMarketCap
  alias Explorer.Market.History.Source.MarketCap, as: SourceMarketCap

  import Source, only: [to_decimal: 1]

  @behaviour SourceMarketCap

  @impl SourceMarketCap
  def fetch_market_cap do
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

  @spec format_data(term()) :: SourceMarketCap.record() | nil
  defp format_data(nil), do: nil

  defp format_data(%{"data" => _} = json_data) do
    market_data = json_data["data"]
    token_properties = ExchangeRatesSourceCoinMarketCap.get_token_properties(market_data)

    last_updated =
      token_properties
      |> ExchangeRatesSourceCoinMarketCap.get_last_updated()
      |> DateTime.to_date()

    market_cap_data_usd = ExchangeRatesSourceCoinMarketCap.get_market_cap_data_usd(token_properties)

    %{
      market_cap: to_decimal(market_cap_data_usd),
      date: last_updated
    }
  end
end
