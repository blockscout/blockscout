defmodule BlockScoutWeb.API.V1.MarketHistoryChartApiController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def market_history_chart(conn, _) do
    APILogger.log(conn)
    try do
      exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

      recent_market_history = Market.fetch_recent_history()

      market_history_data =
        case recent_market_history do
          [today | the_rest] ->
            encode_market_history_data([%{today | closing_price: exchange_rate.usd_value} | the_rest])

          data ->
            encode_market_history_data(data)
        end

      send_resp(conn, :ok, result(market_history_data,
                                  available_supply(Chain.supply_for_days(), exchange_rate)
        )
      )
    rescue
      e in RuntimeError -> send_resp(conn, :internal_server_error, error(e))
    end
  end

  defp result(market_history_data, available_supply) do
    %{
      "history_data" => market_history_data,
      "supply_data" => available_supply
    }
    |> Jason.encode!()
  end

  defp error(e) do
    %{
      "error" => e
    }
    |> Jason.encode!()
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