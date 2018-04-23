defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"transaction_id" => transaction_hash_string} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             necessity_by_association: %{
               block: :optional,
               from_address: :required,
               receipt: :optional,
               to_address: :required
             }
           ) do
      logs =
        Chain.transaction_to_logs(
          transaction,
          necessity_by_association: %{address: :optional},
          pagination: params
        )

      max_block_number = Chain.max_block_number()

      render(
        conn,
        "index.html",
        logs: logs,
        max_block_number: max_block_number,
        transaction: transaction
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
