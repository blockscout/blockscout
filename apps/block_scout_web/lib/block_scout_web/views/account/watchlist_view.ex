defmodule BlockScoutWeb.Account.WatchlistView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Account.WatchlistAddressView
  alias Explorer.Account.WatchlistAddress
  alias Explorer.Market
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand

  def coin_balance_status(address) do
    CoinBalanceOnDemand.trigger_fetch(address)
  end

  def exchange_rate do
    Market.get_coin_exchange_rate()
  end
end
