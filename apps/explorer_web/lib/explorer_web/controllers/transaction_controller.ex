defmodule ExplorerWeb.TransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Transaction
  alias ExplorerWeb.TransactionForm

  def index(conn, %{"last_seen" => last_seen_id}) do
    total = Chain.transaction_count()

    entries =
      last_seen_id
      |> Chain.transactions_recently_before_id(
        necessity_by_association: %{
          block: :required,
          from_address: :optional,
          to_address: :optional,
          receipt: :required
        }
      )
      |> Enum.map(&TransactionForm.build_and_merge/1)

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

        transaction_form = TransactionForm.build_and_merge(transaction)

        render(
          conn,
          "show.html",
          internal_transactions: internal_transactions,
          transaction: transaction_form
        )

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
