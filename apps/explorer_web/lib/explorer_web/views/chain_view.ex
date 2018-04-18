defmodule ExplorerWeb.ChainView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  defdelegate value(transaction), to: TransactionView
end
