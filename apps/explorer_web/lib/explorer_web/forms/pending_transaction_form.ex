defmodule ExplorerWeb.PendingTransactionForm do
  @moduledoc "Format a pending Transaction for display."

  import ExplorerWeb.Gettext

  alias Explorer.Chain.{Address, Transaction}

  # Functions

  def build(transaction) do
    Map.merge(transaction, %{
      first_seen: first_seen(transaction),
      formatted_status: gettext("Pending"),
      from_address_hash: from_address_hash(transaction),
      last_seen: last_seen(transaction),
      status: :pending,
      to_address_hash: to_address_hash(transaction)
    })
  end

  def first_seen(transaction) do
    transaction.inserted_at |> Timex.from_now()
  end

  def from_address_hash(%Transaction{from_address: from_address}) do
    case from_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end

  def last_seen(transaction) do
    transaction.updated_at |> Timex.from_now()
  end

  def to_address_hash(%Transaction{to_address: to_address}) do
    case to_address do
      %Address{hash: hash} -> hash
      _ -> nil
    end
  end
end
