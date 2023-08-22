defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  alias Explorer.ExchangeRates.Token
  alias Explorer.Market.{MarketHistory, MarketHistoryCache}
  alias Explorer.{ExchangeRates, Repo}

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

    Repo.insert_all(MarketHistory, records_without_zeroes, on_conflict: :nothing, conflict_target: [:date])
  end

  @spec get_exchange_rate(String.t()) :: Token.t() | nil
  defp get_exchange_rate(symbol) do
    ExchangeRates.lookup(symbol)
  end
end
