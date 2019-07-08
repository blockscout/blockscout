defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView

  defp market_cap(:standard, exchange_rate) do
    exchange_rate.market_cap_usd
  end

  defp market_cap(module, exchange_rate) do
    module.market_cap(exchange_rate)
  end
end
