defmodule Explorer.Market.History.Source.MarketCap do
  @moduledoc """
  Interface for a source that allows for fetching of market cap history.
  """

  @typedoc """
  Record of market values for a specific date.
  """
  @type record :: %{
          date: Date.t(),
          market_cap: Decimal.t()
        }

  @doc """
  Fetch history for a specified amount of days in the past.
  """
  @callback fetch_market_cap(previous_days :: non_neg_integer()) :: {:ok, [record()]} | :error
end
