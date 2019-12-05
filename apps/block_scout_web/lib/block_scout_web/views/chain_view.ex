defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView

    defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value})
         when is_nil(available_supply) or is_nil(usd_value) do
          IO.inspect("here")
          Decimal.new(0)
    end

    defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value}) do
      IO.inspect("here 2")
      Decimal.mult(available_supply, usd_value)
    end

    defp market_cap(:standard, exchange_rate) do
      IO.inspect("here 3")
      exchange_rate.market_cap_usd
    end

    defp market_cap(module, exchange_rate) do
      IO.inspect("here 4")
      module.market_cap(exchange_rate)
    end

end
