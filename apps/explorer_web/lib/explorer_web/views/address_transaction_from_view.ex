defmodule ExplorerWeb.AddressTransactionFromView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  def status(transacton) do
    TransactionView.status(transacton)
  end
end
