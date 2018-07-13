defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{BlockView, TransactionView}

  defdelegate formatted_status(transaction), to: TransactionView
  defdelegate formatted_timestamp(block), to: BlockView
  defdelegate status(transacton), to: TransactionView
end
