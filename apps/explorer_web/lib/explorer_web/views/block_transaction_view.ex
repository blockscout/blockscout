defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.{BlockView, TransactionView}

  defdelegate formatted_timestamp(block), to: BlockView
end
