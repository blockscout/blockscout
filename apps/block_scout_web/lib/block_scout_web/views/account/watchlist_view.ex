defmodule BlockScoutWeb.Account.WatchlistView do
  use BlockScoutWeb, :view

  alias Explorer.Account.WatchlistAddress
  alias BlockScoutWeb.Account.WatchlistAddressView
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def coin_balance_status(address) do
    CoinBalanceOnDemand.trigger_fetch(address)
  end

  def exchange_rate do
    Market.get_exchange_rate(Explorer.coin()) || Token.null()
  end
end
