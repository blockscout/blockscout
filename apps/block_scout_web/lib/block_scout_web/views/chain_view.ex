defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  def encode_market_history_data(market_history_data) do
    market_history_data
    |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end
end
