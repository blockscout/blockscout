defmodule ExplorerWeb.PendingTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.PendingTransactionForm

  def index(conn, %{"last_seen" => last_seen} = _) do
    query =
      from(
        transaction in Transaction,
        left_join: receipt in assoc(transaction, :receipt),
        inner_join: to_address in assoc(transaction, :to_address),
        inner_join: from_address in assoc(transaction, :from_address),
        preload: [to_address: to_address, from_address: from_address],
        where: is_nil(receipt.transaction_id),
        where: transaction.id < ^last_seen,
        order_by: [desc: transaction.id],
        limit: 10
      )

    total_query =
      from(
        transaction in Transaction,
        left_join: receipt in assoc(transaction, :receipt),
        where: is_nil(receipt.transaction_id),
        order_by: [desc: transaction.id],
        limit: 1
      )

    total =
      case Repo.one(total_query) do
        nil -> 0
        total -> total.id
      end

    entries = Repo.all(query)
    last = List.last(entries) || Transaction.null()

    render(
      conn,
      "index.html",
      transactions: %{
        entries: entries |> Enum.map(&PendingTransactionForm.build/1),
        total_entries: total,
        last_seen: last.id
      }
    )
  end

  def index(conn, params) do
    query =
      from(
        transaction in Transaction,
        select: transaction.id,
        left_join: receipt in assoc(transaction, :receipt),
        where: is_nil(receipt.transaction_id),
        order_by: [desc: transaction.id],
        limit: 1
      )

    first_id = Repo.one(query) || 0
    last_seen = Integer.to_string(first_id + 1)
    index(conn, Map.put(params, "last_seen", last_seen))
  end
end
