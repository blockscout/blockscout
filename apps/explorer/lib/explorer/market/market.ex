defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  alias Explorer.Market.Fetcher.{Coin, History}
  alias Explorer.Market.{MarketHistory, MarketHistoryCache, Token}

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history(boolean()) :: [MarketHistory.t()]
  def fetch_recent_history(secondary_coin? \\ false) do
    if GenServer.whereis(History) do
      MarketHistoryCache.fetch(secondary_coin?)
    else
      []
    end
  end

  @doc """
  Get most recent exchange rate for the native coin from ETS or from DB.
  """
  @spec get_coin_exchange_rate() :: Token.t()
  def get_coin_exchange_rate do
    Coin.get_coin_exchange_rate() || Token.null()
  end

  @doc """
  Get most recent exchange rate for the secondary coin from DB.
  """
  @spec get_secondary_coin_exchange_rate() :: Token.t()
  def get_secondary_coin_exchange_rate do
    Coin.get_secondary_coin_exchange_rate() || Token.null()
  end

  @doc """
  Retrieves the token exchange rate information for a specific date.

  This function fetches historical market data for a given datetime and constructs
  a token record with price information. If the datetime is nil or no market
  history exists for the specified date, returns a null token record.

  ## Parameters
  - `datetime`: The datetime for which to retrieve the exchange rate. If nil,
    returns a null token record.
  - `options`: Additional options for retrieving market history data.

  ## Returns
  - A `Token` struct containing the closing price as fiat value, market cap, and
    TVL from the market history. All other token fields are set to nil.
  - A null token record if datetime is nil or no market history exists for the
    specified date.
  """
  @spec get_coin_exchange_rate_at_date(DateTime.t() | nil, Keyword.t()) :: Token.t()
  def get_coin_exchange_rate_at_date(nil, _options), do: Token.null()

  def get_coin_exchange_rate_at_date(datetime, options) do
    datetime
    |> DateTime.to_date()
    |> MarketHistory.price_at_date(false, options)
    |> MarketHistory.to_token()
  end
end
