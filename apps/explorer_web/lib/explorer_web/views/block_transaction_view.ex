defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{BlockView, TransactionView}

  defdelegate age(block), to: BlockView
  defdelegate block(transaction), to: TransactionView
  defdelegate formatted_timestamp(block), to: BlockView
  defdelegate from_address(transaction), to: TransactionView
  defdelegate hash(transaction), to: TransactionView
  defdelegate status(transacton), to: TransactionView
  defdelegate to_address(transaction), to: TransactionView
end
