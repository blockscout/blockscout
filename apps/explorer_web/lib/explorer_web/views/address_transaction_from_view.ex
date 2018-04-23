defmodule ExplorerWeb.AddressTransactionFromView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  defdelegate block(transaction), to: TransactionView
  defdelegate from_address(transaction), to: TransactionView
  defdelegate hash(transaction), to: TransactionView
  defdelegate status(transacton), to: TransactionView
  defdelegate to_address(transaction), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
