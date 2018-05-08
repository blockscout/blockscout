defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, params) do
    with %{"last_seen_collated_hash" => last_seen_collated_hash_string} <- params,
         {:ok, last_seen_collated_hash} <- Chain.string_to_transaction_hash(last_seen_collated_hash_string) do
      do_index(conn, after_hash: last_seen_collated_hash)
    else
      _ -> do_index(conn)
    end
  end

  def show(conn, %{"id" => hash_string}) do
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

      render(
        conn,
        "show.html",
        internal_transactions: internal_transactions,
        max_block_number: max_block_number(),
        transaction: transaction
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp do_index(conn, options \\ []) when is_list(options) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            block: :required,
            from_address: :optional,
            to_address: :optional,
            receipt: :required
          }
        ],
        options
      )

    transactions = Chain.recent_collated_transactions(full_options)
    last_seen_collated_hash = last_seen_collated_hash(transactions)
    transaction_count = Chain.transaction_count()

    render(
      conn,
      "index.html",
      last_seen_collated_hash: last_seen_collated_hash,
      transaction_count: transaction_count,
      transactions: transactions
    )
  end

  defp last_seen_collated_hash([]), do: nil

  defp last_seen_collated_hash(transactions) do
    List.last(transactions).hash
  end

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end
end
