defmodule BlockScoutWeb.Account.WatchlistAddressView do
  use BlockScoutWeb, :view
  import BlockScoutWeb.AddressView, only: [trimmed_hash: 1]
  import BlockScoutWeb.WeiHelpers, only: [format_wei_value: 2]

  alias Explorer.Chain.Address
  alias Explorer.Chain.Wei
  alias Explorer.Market

  def balance_ether(%Address{fetched_coin_balance: nil}), do: ""

  def balance_ether(%Address{fetched_coin_balance: balance}) do
    format_wei_value(balance, :ether)
  end

  defp exchange_rate do
    Market.get_exchange_rate(Explorer.coin())
  end
end
