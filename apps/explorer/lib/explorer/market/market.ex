defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  alias Explorer.ExchangeRates.Token
  alias Explorer.Market.{MarketHistory, MarketHistoryCache}
  alias Explorer.{ExchangeRates, Repo}

  import Ecto.Query, only: [from: 2]

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history() :: [MarketHistory.t()]
  def fetch_recent_history do
    MarketHistoryCache.fetch()
  end

  @doc """
  Retrieves today's native coin exchange rate from the database.
  """
  @spec get_native_coin_exchange_rate_from_db() :: Token.t()
  def get_native_coin_exchange_rate_from_db do
    today =
      case fetch_recent_history() do
        [today | _the_rest] -> today
        _ -> nil
      end

    if today do
      %Token{
        usd_value: Map.get(today, :closing_price),
        market_cap_usd: Map.get(today, :market_cap),
        tvl_usd: Map.get(today, :tvl),
        available_supply: nil,
        total_supply: nil,
        btc_value: nil,
        id: nil,
        last_updated: nil,
        name: nil,
        symbol: nil,
        volume_24h_usd: nil
      }
    else
      Token.null()
    end
  end

  @doc """
  Get most recent exchange rate for the native coin from ETS or from DB.
  """
  @spec get_coin_exchange_rate() :: Token.t() | nil
  def get_coin_exchange_rate do
    get_exchange_rate(Explorer.coin()) || get_native_coin_exchange_rate_from_db() || Token.null()
  end

  @doc false
  def bulk_insert_history(records) do
    records_without_zeroes =
      records
      |> Enum.reject(fn item ->
        Map.has_key?(item, :opening_price) && Map.has_key?(item, :closing_price) &&
          Decimal.equal?(item.closing_price, 0) &&
          Decimal.equal?(item.opening_price, 0)
      end)
      # Enforce MarketHistory ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(& &1.date)

    Repo.insert_all(MarketHistory, records_without_zeroes,
      on_conflict: market_history_on_conflict(),
      conflict_target: [:date]
    )
  end

  defp market_history_on_conflict do
    from(
      market_history in MarketHistory,
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

  @spec get_exchange_rate(String.t()) :: Token.t() | nil
  defp get_exchange_rate(symbol) do
    ExchangeRates.lookup(symbol)
  end
end
