defmodule Explorer.Market.MarketHistory do
  @moduledoc """
  Represents market history of configured coin to USD.
  """

  use Explorer.Schema

  @typedoc """
  The recorded values of the configured coin to USD for a single day.

   * `:closing_price` - Closing price in USD.
   * `:date` - The date in UTC.
   * `:opening_price` - Opening price in USD.
   * `:market_cap` - Market cap in USD.
   * `:tvl` - TVL in USD.
  """
  typed_schema "market_history" do
    field(:closing_price, :decimal)
    field(:date, :date, null: false)
    field(:opening_price, :decimal)
    field(:market_cap, :decimal)
    field(:tvl, :decimal)
    field(:secondary_coin, :boolean)
  end
end
