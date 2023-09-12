defmodule Explorer.Market.History.Source.MarketCap.CoinGecko do
  @moduledoc """
  Adapter for fetching current market from CoinGecko.

  The current market is fetched for the configured coin. You can specify a
  different coin by changing the targeted coin.

      # In config.exs
      config :explorer, coin: "POA"

  """

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.CoinGecko, as: ExchangeRatesSourceCoinGecko
  alias Explorer.Market.History.Source.MarketCap, as: SourceMarketCap

  @behaviour SourceMarketCap

  @impl SourceMarketCap
  def fetch_market_cap do
    url = ExchangeRatesSourceCoinGecko.source_url()

    if url do
      case Source.http_request(url, ExchangeRatesSourceCoinGecko.headers()) do
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

  defp format_data(data) do
    market_data = data["market_data"]
    market_cap = market_data["market_cap"]

    %{
      market_cap: Decimal.new(to_string(market_cap["usd"])),
      date: ExchangeRatesSourceCoinGecko.date(data["last_updated"])
    }
  end
end
