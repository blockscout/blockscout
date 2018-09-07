defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain

  def index(conn, params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            block: :required,
            from_address: :optional,
            to_address: :optional
          }
        ],
        paging_options(params)
      )

    transactions_plus_one = Chain.recent_collated_transactions(full_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    transaction_estimated_count = Chain.transaction_estimated_count()

    render(
      conn,
      "index.html",
      next_page_params: next_page_params(next_page, transactions, params),
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions
    )
  end

  def show(conn, %{"id" => id}) do
    {:ok, transaction_hash} = Chain.string_to_transaction_hash(id)

    if Chain.transaction_has_token_transfers?(transaction_hash) do
      redirect(conn, to: transaction_token_transfer_path(conn, :index, id))
    else
      redirect(conn, to: transaction_internal_transaction_path(conn, :index, id))
    end
  end
end
