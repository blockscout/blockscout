defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{BlockView, TransactionView}

  defdelegate age(block), to: BlockView
  defdelegate formatted_timestamp(block), to: BlockView
  defdelegate status(transacton), to: TransactionView
end
