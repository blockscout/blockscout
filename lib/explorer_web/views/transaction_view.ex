defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  def format_gas_limit(gas) do
    gas
    |> Cldr.Number.to_string!
  end
end
