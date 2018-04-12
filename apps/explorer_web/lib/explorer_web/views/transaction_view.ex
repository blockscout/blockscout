defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  @dialyzer :no_match

  def format_gas_limit(gas) do
    gas
    |> Number.to_string!()
  end
end
