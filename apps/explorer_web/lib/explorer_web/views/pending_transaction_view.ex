defmodule ExplorerWeb.PendingTransactionView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, Transaction}
  alias ExplorerWeb.TransactionView

  @dialyzer :no_match

  # Functions

  def from_address_hash(%Transaction{from_address: from_address}) do
    case from_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end

  def last_seen(transaction) do
    TransactionView.last_seen(transaction)
  end

  def to_address_hash(%Transaction{to_address: to_address}) do
    case to_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end
end
