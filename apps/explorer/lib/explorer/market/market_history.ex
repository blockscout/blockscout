defmodule Explorer.Market.MarketHistory do
  @moduledoc """
  Represents market history of configured coin to VND.
  """

  use Explorer.Schema

  schema "market_history" do
    field(:closing_price, :decimal)
    field(:date, :date)
    field(:opening_price, :decimal)
  end

  @typedoc """
  The recorded values of the configured coin to VND for a single day.

   * `:closing_price` - Closing price in VND.
   * `:date` - The date in UTC.
   * `:opening_price` - Opening price in VND.
  """
  @type t :: %__MODULE__{
          closing_price: Decimal.t(),
          date: Date.t(),
          opening_price: Decimal.t()
        }
end
