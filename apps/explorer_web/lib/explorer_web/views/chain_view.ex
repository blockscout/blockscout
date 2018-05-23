defmodule ExplorerWeb.ChainView do
  use ExplorerWeb, :view

  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.ExchangeRates.USD

  def encode_market_history_data(market_history_data) do
    market_history_data
    |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end

  def format_exchange_rate(%Token{usd_value: usd_value}) do
    usd_value
    |> USD.from()
    |> format_usd_value()
  end

  def format_volume_24h(%Token{volume_24h_usd: volume_24h}) do
    volume_24h
    |> USD.from()
    |> format_usd_value()
  end

  def format_market_cap(%Token{market_cap_usd: market_cap}) do
    market_cap
    |> USD.from()
    |> format_usd_value()
  end
end
