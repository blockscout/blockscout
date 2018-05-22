defmodule ExplorerWeb.PendingTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  @dialyzer :no_match

  defdelegate last_seen(transaction), to: TransactionView
end
