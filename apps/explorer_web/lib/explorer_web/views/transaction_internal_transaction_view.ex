defmodule ExplorerWeb.TransactionInternalTransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias ExplorerWeb.TransactionView

  defdelegate value(txn, opts), to: TransactionView
  defdelegate gas(txn), to: TransactionView
end
