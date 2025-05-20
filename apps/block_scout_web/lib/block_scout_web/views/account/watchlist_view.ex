defmodule BlockScoutWeb.Account.WatchlistView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Account.WatchlistAddressView
  alias Explorer.Account.WatchlistAddress
  alias Explorer.Market

  def exchange_rate do
    Market.get_coin_exchange_rate()
  end
end
