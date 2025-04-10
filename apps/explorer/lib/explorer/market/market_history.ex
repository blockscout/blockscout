defmodule Explorer.Market.MarketHistory do
  @moduledoc """
  Represents market history of configured coin to USD.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Market.Token

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

  @doc false
  @spec bulk_insert([map()]) :: {non_neg_integer(), nil | [term()]}
  def bulk_insert(records) do
    records_without_zeroes =
      records
      |> Enum.reject(fn item ->
        Map.has_key?(item, :opening_price) && Map.has_key?(item, :closing_price) &&
          Decimal.equal?(item.closing_price, 0) &&
          Decimal.equal?(item.opening_price, 0)
      end)
      # Enforce MarketHistory ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(& &1.date)

    Repo.safe_insert_all(__MODULE__, records_without_zeroes,
      on_conflict: market_history_on_conflict(),
      conflict_target: [:date, :secondary_coin]
    )
  end

  @spec to_token(t() | nil) :: Token.t()
  def to_token(%__MODULE__{} = market_history) do
    %Token{
      fiat_value: market_history.closing_price,
      market_cap: market_history.market_cap,
      tvl: market_history.tvl,
      available_supply: nil,
      total_supply: nil,
      btc_value: nil,
      last_updated: nil,
      name: nil,
      symbol: nil,
      volume_24h: nil,
      image_url: nil
    }
  end

  def to_token(_), do: Token.null()

  defp market_history_on_conflict do
    from(
      market_history in __MODULE__,
      update: [
        set: [
          opening_price:
            fragment(
              """
              CASE WHEN (? IS NULL OR ? = 0) AND EXCLUDED.opening_price IS NOT NULL AND EXCLUDED.opening_price > 0
              THEN EXCLUDED.opening_price
              ELSE ?
              END
              """,
              market_history.opening_price,
              market_history.opening_price,
              market_history.opening_price
            ),
          closing_price:
            fragment(
              """
              CASE WHEN (? IS NULL OR ? = 0) AND EXCLUDED.closing_price IS NOT NULL AND EXCLUDED.closing_price > 0
              THEN EXCLUDED.closing_price
              ELSE ?
              END
              """,
              market_history.closing_price,
              market_history.closing_price,
              market_history.closing_price
            ),
          market_cap:
            fragment(
              """
              CASE WHEN (? IS NULL OR ? = 0) AND EXCLUDED.market_cap IS NOT NULL AND EXCLUDED.market_cap > 0
              THEN EXCLUDED.market_cap
              ELSE ?
              END
              """,
              market_history.market_cap,
              market_history.market_cap,
              market_history.market_cap
            ),
          tvl:
            fragment(
              """
              CASE WHEN (? IS NULL OR ? = 0) AND EXCLUDED.tvl IS NOT NULL AND EXCLUDED.tvl > 0
              THEN EXCLUDED.tvl
              ELSE ?
              END
              """,
              market_history.tvl,
              market_history.tvl,
              market_history.tvl
            )
        ]
      ],
      where:
        is_nil(market_history.tvl) or market_history.tvl == 0 or is_nil(market_history.market_cap) or
          market_history.market_cap == 0 or is_nil(market_history.opening_price) or
          market_history.opening_price == 0 or is_nil(market_history.closing_price) or
          market_history.closing_price == 0
    )
  end
end
