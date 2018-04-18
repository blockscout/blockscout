defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  # Functions

  defdelegate status(transacton), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
