defmodule ExplorerWeb.InternalTransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.InternalTransaction

  def create?(%InternalTransaction{type: :create}), do: true
  def create?(_), do: false
end
