defmodule Explorer.SkippedReceipts do
  @moduledoc """
    Find transactions that do not have a receipt.
  """
  import Ecto.Query, only: [from: 2]

  alias Explorer.Transaction
  alias Explorer.Repo.NewRelic, as: Repo

  def first, do: first(1)
  def first(count) do
    transactions = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      select: fragment("hash"),
      where: is_nil(receipt.id),
      limit: ^count
    Repo.all(transactions)
  end
end
