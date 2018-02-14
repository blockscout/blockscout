defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, %{"last_seen" => last_seen} = _) do
    query = from transaction in Transaction,
      where: transaction.id < ^last_seen,
      inner_join: receipt in assoc(transaction, :receipt),
      inner_join: block in assoc(transaction, :block),
      inner_join: to_address in assoc(transaction, :to_address),
      inner_join: from_address in assoc(transaction, :from_address),
      preload: [
        block: block, receipt: receipt,
        to_address: to_address, from_address: from_address],
      order_by: [desc: transaction.id],
      limit: 100
    total_query = from transaction in Transaction,
      select: fragment("count(?)", transaction.id),
      inner_join: receipt in assoc(transaction, :receipt),
      inner_join: block in assoc(transaction, :block)
    entries =
      query
      |> Repo.all()
      |> Enum.map(&TransactionForm.build_and_merge/1)
    last = List.last(entries) || Transaction.null
    render(conn, "index.html", transactions: %{
      entries: entries,
      total_entries: Repo.one(total_query),
      last_seen: last.id
    })
  end

  def index(conn, params) do
    query = from t in Transaction,
      select: t.id,
      order_by: [desc: t.id],
      limit: 1
    first_id = Repo.one(query) || 0
    last_seen = Integer.to_string(first_id + 1)
    index(conn, Map.put(params, "last_seen", last_seen))
  end

  def show(conn, params) do
    hash = String.downcase(params["id"])
    query = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      left_join: block in assoc(transaction, :block),
      inner_join: to_address in assoc(transaction, :to_address),
      inner_join: from_address in assoc(transaction, :from_address),
      preload: [
        block: block, receipt: receipt,
        to_address: to_address, from_address: from_address],
      where: fragment("lower(?)", transaction.hash) == ^hash,
      limit: 1

    transaction = query |> Repo.one() |> TransactionForm.build_and_merge()

    render(conn, "show.html", transaction: transaction)
  end
end
