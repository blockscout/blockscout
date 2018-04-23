defmodule ExplorerWeb.PendingTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  @dialyzer :no_match

  # Functions

  defdelegate from_address(transaction), to: TransactionView
  defdelegate hash(transaction), to: TransactionView
  defdelegate last_seen(transaction), to: TransactionView
  defdelegate to_address(transaction), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
