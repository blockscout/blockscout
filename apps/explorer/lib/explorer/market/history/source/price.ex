defmodule Explorer.Market.History.Source.Price do
  @moduledoc """
  Interface for a source that allows for fetching of coin price.
  """

  @typedoc """
  Record of market values for a specific date.
  """
  @type record :: %{
          closing_price: Decimal.t(),
          date: Date.t(),
          opening_price: Decimal.t(),
          secondary_coin: boolean()
        }

  @doc """
  Fetch history for a specified amount of days in the past.
  """
  @callback fetch_price_history(previous_days :: non_neg_integer(), secondary_coin :: boolean()) ::
              {:ok, [record()]} | :error
end
