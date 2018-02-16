defmodule ExplorerWeb.AddressTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Address
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, %{"address_id" => address_id} = params) do
    hash = String.downcase(address_id)
    address = Repo.one(from address in Address,
      where: fragment("lower(?)", address.hash) == ^hash,
      limit: 1)
    address_id = address.id
    query = from transaction in Transaction,
      join: block in assoc(transaction, :block),
      join: receipt in assoc(transaction, :receipt),
      join: from_address in assoc(transaction, :from_address),
      join: to_address in assoc(transaction, :to_address),
      preload: [:block, :receipt, :to_address, :from_address],
      order_by: [desc: transaction.inserted_at],
      where: to_address.id == ^address_id or from_address.id == ^address_id
    page = Repo.paginate(query, params)
    entries = Enum.map(page.entries, &TransactionForm.build_and_merge/1)
    render(conn, "index.html", transactions: Map.put(page, :entries, entries))
  end
end
