defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  def format_balance(nil), do: "0"

  def format_balance(balance) do
    balance
    |> Decimal.new()
    |> Decimal.div(Decimal.new(1_000_000_000_000_000_000))
    |> Decimal.to_string(:normal)
  end
end
