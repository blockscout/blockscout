defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias ExplorerWeb.TransactionForm

  def index(conn, %{"transaction_id" => transaction_hash} = params) do
    case Chain.hash_to_transaction(
           transaction_hash,
           necessity_by_association: %{from_address: :required, to_address: :required}
         ) do
      {:ok, transaction} ->
        logs =
          Chain.transaction_to_logs(
            transaction,
            necessity_by_association: %{address: :optional},
            pagination: params
          )

        transaction_form = TransactionForm.build_and_merge(transaction)

        render(conn, "index.html", logs: logs, transaction: transaction_form)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
