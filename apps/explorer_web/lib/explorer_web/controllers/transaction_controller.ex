defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  def index(conn, %{"last_seen" => last_seen_id}) do
    total = Chain.transaction_count()

    entries =
      Chain.transactions_recently_before_id(
        last_seen_id,
        necessity_by_association: %{
          block: :required,
          from_address: :optional,
          to_address: :optional,
          receipt: :required
        }
      )

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
    last_seen =
      Chain.last_transaction_id()
      |> Kernel.+(1)
      |> Integer.to_string()

    index(conn, Map.put(params, "last_seen", last_seen))
  end

  def show(conn, params) do
    case Chain.hash_to_transaction(
           params["id"],
           necessity_by_association: %{
             block: :optional,
             from_address: :optional,
             to_address: :optional,
             receipt: :optional
           }
         ) do
      {:ok, transaction} ->
        internal_transactions =
          Chain.transaction_hash_to_internal_transactions(
            transaction.hash,
            necessity_by_association: %{from_address: :required, to_address: :required}
          )

        max_block_number = Chain.max_block_number()

        render(
          conn,
          "show.html",
          internal_transactions: internal_transactions,
          max_block_number: max_block_number,
          transaction: transaction
        )

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
