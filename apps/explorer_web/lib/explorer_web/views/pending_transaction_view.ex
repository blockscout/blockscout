defmodule ExplorerWeb.PendingTransactionView do
  use ExplorerWeb, :view

  @dialyzer :no_match

  alias ExplorerWeb.TransactionView

  defdelegate formatted_status(transaction), to: TransactionView
  defdelegate status(transaction), to: TransactionView
end
