defmodule Explorer.Market.History.Source.Price.CoinGecko do
  @moduledoc """
  Adapter for fetching current market from CoinGecko.
  """

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.CoinGecko, as: ExchangeRatesSourceCoinGecko
  alias Explorer.Market.History.Source.Price, as: SourcePrice

  @behaviour SourcePrice

  @impl SourcePrice
  def fetch_price_history(_previous_days \\ nil) do
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

  @spec format_data(term()) :: SourcePrice.record() | nil
  defp format_data(nil), do: nil

  defp format_data(data) do
    market_data = data["market_data"]
    current_price = market_data["current_price"]
    current_price_usd = Decimal.new(to_string(current_price["usd"]))
    price_change_percentage_24h_in_currency = market_data["price_change_percentage_24h_in_currency"]

    delta_perc = Decimal.new(to_string(price_change_percentage_24h_in_currency["usd"]))

    delta =
      current_price_usd
      |> Decimal.mult(delta_perc)
      |> Decimal.div(100)

    opening_price = Decimal.add(current_price_usd, delta)

    [
      %{
        closing_price: current_price_usd,
        date: ExchangeRatesSourceCoinGecko.date(data["last_updated"]),
        opening_price: opening_price
      }
    ]
  end
end
