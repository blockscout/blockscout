defmodule Explorer.Market.MarketHistory do
  @moduledoc """
  Represents market history of configured coin to USD.
  """

  use Explorer.Schema

  alias Explorer.Chain

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
    field(:secondary_coin, :boolean, default: false)
  end

  @doc """
  Returns the market history (for the secondary coin if specified) for the given date.
  """
  @spec price_at_date(Date.t(), boolean(), [Chain.api?()]) :: t() | nil
  def price_at_date(date, secondary_coin? \\ false, options \\ []) do
    query =
      from(
        mh in __MODULE__,
        where: mh.date == ^date and mh.secondary_coin == ^secondary_coin?
      )

    Chain.select_repo(options).one(query)
  end
end
