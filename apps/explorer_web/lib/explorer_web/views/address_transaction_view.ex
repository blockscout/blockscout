defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{AddressView, TransactionView}

  defdelegate balance(address), to: AddressView
  defdelegate status(transacton), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
