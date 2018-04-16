defmodule ExplorerWeb.BlockTransactionView do
  use ExplorerWeb, :view

  alias Explorer.Chain.Transaction
  alias ExplorerWeb.TransactionView

  # Functions

  def status(%Transaction{} = transaction) do
    TransactionView.status(transaction)
  end
end
