defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Log
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm
  alias Explorer.Transaction.Service
  alias Explorer.Transaction.Service.Query

  def index(conn, %{"last_seen" => last_seen}) do
    query =
      Transaction
      |> Query.recently_seen(last_seen)
      |> Query.include_addresses()
      |> Query.require_receipt()
      |> Query.require_block()

    total_query =
      from(
        transaction in Transaction,
        order_by: [desc: transaction.id],
        limit: 1
      )

    total =
      case Repo.one(total_query) do
        nil -> 0
        total -> total.id
      end

    entries =
      query
      |> Repo.all()
      |> Enum.map(&TransactionForm.build_and_merge/1)

    last = List.last(entries) || Transaction.null()

    render(
      conn,
      "index.html",
      transactions: %{
        entries: entries,
        total_entries: total,
        last_seen: last.id
      }
    )
  end

  def index(conn, params) do
    query =
      from(
        t in Transaction,
        select: t.id,
        order_by: [desc: t.id],
        limit: 1
      )

    first_id = Repo.one(query) || 0
    last_seen = Integer.to_string(first_id + 1)
    index(conn, Map.put(params, "last_seen", last_seen))
  end

  def show(conn, params) do
    transaction =
      Transaction
      |> Query.by_hash(String.downcase(params["id"]))
      |> Query.include_addresses()
      |> Query.include_receipt()
      |> Query.include_block()
      |> Repo.one()
      |> TransactionForm.build_and_merge()

    internal_transactions = Service.internal_transactions(transaction.hash)

    render(
      conn,
      internal_transactions: internal_transactions,
      transaction: transaction
    )
  end
end
