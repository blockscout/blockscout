defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view

  alias Explorer.Chain

  @dialyzer :no_match

  def balance(address) do
    address
    |> Chain.balance(:ether)
    |> case do
      nil -> ""
      ether -> Cldr.Number.to_string!(ether)
    end
  end
end
