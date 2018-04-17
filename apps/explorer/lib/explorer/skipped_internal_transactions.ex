defmodule Explorer.SkippedInternalTransactions do
  @moduledoc """
    Find transactions that do not have internal transactions.
  """
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Transaction
  alias Explorer.Repo.NewRelic, as: Repo

  def first, do: first(1)

  def first(count) do
    transactions =
      from(
        transaction in Transaction,
        left_join: internal_transactions in assoc(transaction, :internal_transactions),
        select: fragment("hash"),
        group_by: transaction.id,
        having: count(internal_transactions.id) == 0,
        limit: ^count
      )

    Repo.all(transactions)
  end
end
