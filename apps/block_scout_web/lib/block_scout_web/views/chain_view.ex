defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView

  defp market_cap(:standard, exchange_rate) do
    Decimal.mult(exchange_rate.available_supply, exchange_rate.usd_value)
  end

  defp market_cap(module, exchange_rate) do
    module.market_cap(exchange_rate)
  end
end
