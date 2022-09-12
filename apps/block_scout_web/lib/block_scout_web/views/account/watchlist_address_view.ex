defmodule BlockScoutWeb.Account.WatchlistAddressView do
  use BlockScoutWeb, :view
  import BlockScoutWeb.AddressView, only: [trimmed_hash: 1]
  import BlockScoutWeb.WeiHelpers, only: [format_wei_value: 2]

  def balance_ether(nil), do: ""

  def balance_ether(balance) do
    format_wei_value(balance, :ether)
  end
end
