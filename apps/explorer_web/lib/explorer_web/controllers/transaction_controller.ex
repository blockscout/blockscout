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

  def show(conn, %{"id" => id, "locale" => locale}) do
    redirect(conn, to: transaction_internal_transaction_path(conn, :index, locale, id))
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
end
