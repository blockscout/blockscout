defmodule BlockScoutWeb.RecentTransactionsController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Hash
  alias Phoenix.View

  def index(conn, _params) do
    if ajax?(conn) do
      recent_transactions =
        Chain.recent_collated_transactions(
          necessity_by_association: %{
            :block => :required,
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          },
          paging_options: %PagingOptions{page_size: 5}
        )

      transactions =
        Enum.map(recent_transactions, fn transaction ->
          %{
            transaction_hash: Hash.to_string(transaction.hash),
            transaction_html:
              View.render_to_string(BlockScoutWeb.TransactionView, "_tile.html", transaction: transaction, conn: conn)
          }
        end)

      json(conn, %{transactions: transactions})
    else
      unprocessable_entity(conn)
    end
  end
end
