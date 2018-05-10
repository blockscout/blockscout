defmodule ExplorerWeb.ChainView do
  use ExplorerWeb, :view

  alias Explorer.ExchangeRates.Token

  def encode_market_history_data(market_history_data) do
    market_history_data
    |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end

  def format_exchange_rate(%Token{usd_value: nil}), do: nil

  def format_exchange_rate(%Token{usd_value: usd_value}) do
    Cldr.Number.to_string!(usd_value, fractional_digits: 6)
  end

  def format_volume_24h(%Token{volume_24h_usd: volume_24h}) do
    format_number(volume_24h)
  end

  def format_market_cap(%Token{market_cap_usd: market_cap}) do
    format_number(market_cap)
  end

  defp format_number(nil), do: nil
  defp format_number(number), do: Cldr.Number.to_string!(number)
end
