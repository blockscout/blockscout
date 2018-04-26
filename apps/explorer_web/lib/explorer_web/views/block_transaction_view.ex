defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{BlockView, TransactionView}

  # Functions

  defdelegate status(transacton), to: TransactionView
  defdelegate value(transaction), to: TransactionView
  defdelegate age(block), to: BlockView
  defdelegate formatted_timestamp(block), to: BlockView
end
