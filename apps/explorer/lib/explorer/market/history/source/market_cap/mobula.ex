defmodule Explorer.Market.History.Source.MarketCap.Mobula do
  @moduledoc """
  Adapter for fetching current market from Mobula.

  The current market is fetched for the configured coin. You can specify a
  different coin by changing the targeted coin.

      # In config.exs
      config :explorer, coin: "POA"

  """

  require Logger

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.Mobula, as: ExchangeRatesSourceMobula
  alias Explorer.Market.History.Source.MarketCap, as: SourceMarketCap
  alias Explorer.Market.History.Source.Price.CryptoCompare

  @behaviour SourceMarketCap

  @impl SourceMarketCap
  def fetch_market_cap(previous_days) do
    url = ExchangeRatesSourceMobula.market_cap_history_url(previous_days)

    case Source.http_request(url, ExchangeRatesSourceMobula.headers()) do
      {:ok, data} ->
        result =
          data
          |> format_data()

        {:ok, result}

      _ ->
        :error
    end
  end

  @spec format_data(term()) :: SourceMarketCap.record() | nil
  defp format_data(nil), do: nil

  defp format_data(data) do
    market_caps = data["data"]["market_cap_history"]

    for [date, market_cap] <- market_caps do
      date = Decimal.to_integer(Decimal.round(Decimal.from_float(date / 1000)))

      %{
        market_cap: Decimal.new(to_string(market_cap)),
        date: CryptoCompare.date(date)
      }
    end
  end
end
