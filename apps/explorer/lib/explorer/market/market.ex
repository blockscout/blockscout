defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  alias Explorer.ExchangeRates.Token
  alias Explorer.Market.{MarketHistory, MarketHistoryCache}
  alias Explorer.{ExchangeRates, Repo}

  @doc """
  Get most recent exchange rate for the given symbol.
  """
  @spec get_exchange_rate(String.t()) :: Token.t() | nil
  def get_exchange_rate(symbol) do
    ExchangeRates.lookup(symbol)
  end

  @spec get_exchange_rate(String.t(), String.t()) :: Token.t() | nil
  def get_exchange_rate(token_contract_address_hash, symbol) do
    ExchangeRates.lookup_by_address(token_contract_address_hash, symbol)
  end

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history() :: [MarketHistory.t()]
  def fetch_recent_history do
    MarketHistoryCache.fetch()
  end

  @doc false
  def bulk_insert_history(records) do
    records_without_zeroes =
      records
      |> Enum.reject(fn item ->
        Decimal.equal?(item.closing_price, 0) && Decimal.equal?(item.opening_price, 0)
      end)
      # Enforce MarketHistory ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(& &1.date)

    Repo.insert_all(MarketHistory, records_without_zeroes, on_conflict: :nothing, conflict_target: [:date])
  end
end
