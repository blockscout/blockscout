defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  import Ecto.Query

  alias Explorer.{ExchangeRates, Repo}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market.MarketHistory

  @doc """
  Get most recent exchange rate for the given symbol.
  """
  @spec get_exchange_rate(String.t()) :: Token.t() | nil
  def get_exchange_rate(symbol) do
    ExchangeRates.lookup(symbol)
  end

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history(non_neg_integer()) :: [MarketHistory.t()]
  def fetch_recent_history(days) when days >= 1 do
    day_diff = days * -1

    query =
      from(
        mh in MarketHistory,
        where: mh.date > date_add(^Date.utc_today(), ^day_diff, "day"),
        order_by: [desc: mh.date]
      )

    Repo.all(query)
  end

  @doc false
  def bulk_insert_history(records) do
    Repo.insert_all(MarketHistory, records, on_conflict: :replace_all, conflict_target: [:date])
  end
end
