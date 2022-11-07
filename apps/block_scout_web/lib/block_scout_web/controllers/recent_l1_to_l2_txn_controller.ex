defmodule BlockScoutWeb.RecentL1ToL2TxnController do
  use BlockScoutWeb, :controller
  require Logger

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Hash
  alias Phoenix.View


  def index(conn, _params) do
    if ajax?(conn) do
      recent_l1_to_l2_txn =
        Chain.recent_collated_l1_to_l2(
          paging_options: %PagingOptions{page_size: 6}
        )
      l1_to_l2_txn =
        Enum.map(recent_l1_to_l2_txn, fn l1_to_l2 ->
          %{
            l1_to_l2_txn_html:
              View.render_to_string(BlockScoutWeb.L1ToL2TxnView, "_recent_tile.html",
                l1_to_l2: l1_to_l2,
                conn: conn
              )
          }
        end)
      json(conn, %{l1_to_l2_txn: l1_to_l2_txn})
    else
      unprocessable_entity(conn)
    end
  end
end
