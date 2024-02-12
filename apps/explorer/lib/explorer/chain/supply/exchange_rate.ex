defmodule Explorer.Chain.Supply.ExchangeRate do
  @moduledoc """
  Defines the supply API for calculating supply for coins from exchange_rate..
  """

  use Explorer.Chain.Supply

  alias Explorer.Market

  def circulating do
    exchange_rate().available_supply
  end

  def total do
    exchange_rate().total_supply
  end

  def exchange_rate do
    Market.get_coin_exchange_rate()
  end
end
