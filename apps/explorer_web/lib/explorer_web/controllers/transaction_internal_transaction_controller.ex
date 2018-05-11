defmodule ExplorerWeb.TransactionInternalTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"transaction_id" => hash_string}) do
    with {:ok, hash} <- Chain.string_to_transaction_hash(hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             hash,
             necessity_by_association: %{
               block: :optional,
               from_address: :optional,
               to_address: :optional,
               receipt: :optional
             }
           ) do
      internal_transactions =
        Chain.transaction_hash_to_internal_transactions(
          transaction.hash,
          necessity_by_association: %{from_address: :required, to_address: :optional}
        )

      max_block_number = max_block_number()

      render(
        conn,
        "index.html",
        internal_transactions: internal_transactions,
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

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end
end
