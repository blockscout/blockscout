defmodule ExplorerWeb.InternalTransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.InternalTransaction

  def contract?(%InternalTransaction{type: :create}), do: true
  def contract?(_), do: false
end
