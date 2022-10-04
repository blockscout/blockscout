defmodule BlockScoutWeb.API.V2.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [next_page_params: 3, paging_options: 1, put_key_value_to_paging_options: 3, split_list_by_page: 1]

  alias BlockScoutWeb.API.V2.TransactionView
  alias BlockScoutWeb.BlockTransactionController
  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def address(conn, %{"address_hash" => address_hash}) do
    conn
    |> put_status(200)
    |> render(:address, %{address: %{}})
  end
end
