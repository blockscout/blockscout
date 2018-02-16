defmodule ExplorerWeb.BlockTransactionController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction
  alias Explorer.TransactionForm

  def index(conn, %{"block_id" => block_number} = params) do
    query = from transaction in Transaction,
      join: block in assoc(transaction, :block),
      join: receipt in assoc(transaction, :receipt),
      join: from_address in assoc(transaction, :from_address),
      join: to_address in assoc(transaction, :to_address),
      preload: [:block, :receipt, :to_address, :from_address],
      order_by: [desc: transaction.inserted_at],
      where: block.number == ^block_number
    page = Repo.paginate(query, params)
    entries = Enum.map(page.entries, &TransactionForm.build_and_merge/1)
    render(conn, "index.html", transactions: Map.put(page, :entries, entries))
  end
end
