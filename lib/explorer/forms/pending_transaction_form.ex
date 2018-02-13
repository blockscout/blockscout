defmodule Explorer.PendingTransactionForm do
  @moduledoc "Format a pending Transaction for display."

  def build(transaction) do
    Map.merge(transaction, %{
      to_address_hash: transaction |> to_address_hash,
      from_address_hash: transaction |> from_address_hash,
      first_seen: transaction |> first_seen,
      last_seen: transaction |> last_seen,
    })
  end

  def to_address_hash(transaction) do
    transaction.to_address && transaction.to_address.hash || nil
  end

  def from_address_hash(transaction) do
    transaction.to_address && transaction.from_address.hash || nil
  end

  def first_seen(transaction) do
    transaction.inserted_at |> Timex.from_now
  end

  def last_seen(transaction) do
    transaction.updated_at |> Timex.from_now
  end
end
