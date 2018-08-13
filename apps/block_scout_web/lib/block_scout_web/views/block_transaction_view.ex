defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.BlockView

  defdelegate formatted_timestamp(block), to: BlockView
end
