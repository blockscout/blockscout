defmodule BlockScoutWeb.AddressTokenBalanceView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.AddressTokensUsdSum

  def tokens_count_title(token_balances) do
    ngettext("%{count} token", "%{count} tokens", Enum.count(token_balances))
  end

  def filter_by_type(token_balances, type) do
    Enum.filter(token_balances, fn token_balance -> token_balance.token.type == type end)
  end

  def address_tokens_usd_sum_cache(address, token_balances) do
    AddressTokensUsdSum.fetch(address, token_balances)
  end
end
