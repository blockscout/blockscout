defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  defdelegate status(transacton), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
