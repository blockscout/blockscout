defmodule BlockScoutWeb.RecentTxnBatchesController do
  use BlockScoutWeb, :controller
  require Logger

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Hash
  alias Phoenix.View


  def index(conn, _params) do
    if ajax?(conn) do
      recent_txn_batches =
        Chain.recent_collated_txn_batches(
          paging_options: %PagingOptions{page_size: 5}
        )
      txn_batches =
        Enum.map(recent_txn_batches, fn txn_batch ->
          %{
            transaction_html:
              View.render_to_string(BlockScoutWeb.TxnBatchView, "_recent_tile.html",
                txn_batch: txn_batch,
                conn: conn
              )
          }
        end)

      json(conn, %{transactions: txn_batches})
    else
      unprocessable_entity(conn)
    end
  end
end
