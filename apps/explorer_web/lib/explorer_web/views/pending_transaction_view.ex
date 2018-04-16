defmodule ExplorerWeb.PendingTransactionView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, Transaction}

  @dialyzer :no_match

  # Functions

  def from_address_hash(%Transaction{from_address: from_address}) do
    case from_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end

  def last_seen(%Transaction{updated_at: updated_at}) do
    Timex.from_now(updated_at)
  end

  def to_address_hash(%Transaction{to_address: to_address}) do
    case to_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end
end
