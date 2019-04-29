defmodule Explorer.Chain.Supply.CoinMarketCap do
  @moduledoc """
  Defines the supply API for calculating supply for coins from coinmarketcap.
  """

  use Explorer.Chain.Supply

  alias Explorer.ExchangeRates.Token
  alias Explorer.Market

  def circulating do
    exchange_rate().available_supply
  end

  def total do
    exchange_rate().total_supply
  end

  def exchange_rate do
    Market.get_exchange_rate(Explorer.coin()) || Token.null()
  end
end
