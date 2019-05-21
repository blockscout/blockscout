defmodule BlockScoutWeb.AddressCoinBalanceView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Wei

  def format(%Wei{} = value) do
    format_wei_value(value, :ether)
  end

  def delta_arrow(value) do
    if Wei.sign(value) == 1 do
      "▲"
    else
      "▼"
    end
  end

  def delta_sign(value) do
    if Wei.sign(value) == 1 do
      "Positive"
    else
      "Negative"
    end
  end

  def format_delta(%Wei{value: value}) do
    value
    |> Decimal.abs()
    |> Wei.from(:wei)
    |> format_wei_value(:ether)
  end
end
