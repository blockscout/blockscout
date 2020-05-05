defmodule BlockScoutWeb.Chain.MarketHistoryChartController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def show(conn, _params) do
    if ajax?(conn) do
      exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

      recent_market_history = Market.fetch_recent_history()

      market_history_data =
        case recent_market_history do
          [today | the_rest] ->
            encode_market_history_data([%{today | closing_price: exchange_rate.usd_value} | the_rest])

          data ->
            encode_market_history_data(data)
        end

      json(conn, %{
        history_data: market_history_data,
        supply_data: available_supply(Chain.supply_for_days(), exchange_rate)
      })
    else
      unprocessable_entity(conn)
    end
  end

  defp available_supply(:ok, exchange_rate) do
    to_string(exchange_rate.available_supply || 0)
  end

  defp available_supply({:ok, supply_for_days}, _exchange_rate) do
    supply_for_days
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end

  defp encode_market_history_data(market_history_data) do
    market_history_data
    |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end
end
