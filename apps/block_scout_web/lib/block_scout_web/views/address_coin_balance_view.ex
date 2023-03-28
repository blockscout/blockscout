defmodule BlockScoutWeb.AddressCoinBalanceView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain.Wei

  def format(%Wei{} = value) do
    format_wei_value(value, :ether)
  end

  def delta_arrow(value) do
    if value.sign == 1 do
      "▲"
    else
      "▼"
    end
  end

  def delta_sign(value) do
    if value.sign == 1 do
      "Positive"
    else
      "Negative"
    end
  end

  def format_delta(%Decimal{} = value) do
    value
    |> Decimal.abs()
    |> Wei.from(:wei)
    |> format_wei_value(:ether)
  end
end
