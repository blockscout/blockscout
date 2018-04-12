defmodule ExplorerWeb.AddressTransactionFromController do
  @moduledoc """
    Display all the Transactions that originate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Address.Service, as: Address
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.Transaction.Service.Query
  alias Explorer.TransactionForm

  def index(conn, %{"address_id" => address_id} = params) do
    address = Address.by_hash(address_id)

    query =
      Transaction
      |> Query.from_address(address.id)
      |> Query.include_addresses()
      |> Query.require_receipt()
      |> Query.require_block()
      |> Query.chron()

    page = Repo.paginate(query, params)
    entries = Enum.map(page.entries, &TransactionForm.build_and_merge/1)
    render(conn, "index.html", transactions: Map.put(page, :entries, entries))
  end
end
