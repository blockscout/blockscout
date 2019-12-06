defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView

  defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value})
       when is_nil(available_supply) or is_nil(usd_value) do
    Decimal.new(0)
  end

  defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value}) do
    Decimal.mult(available_supply, usd_value)
  end

  defp market_cap(:standard, exchange_rate) do
    exchange_rate.market_cap_usd
  end

  defp market_cap(module, exchange_rate) do
    module.market_cap(exchange_rate)
  end
end
