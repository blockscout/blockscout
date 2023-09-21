defmodule BlockScoutWeb.API.V2.PolygonSupernetController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain
  alias Explorer.Chain.{PolygonSupernetDepositExecute}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Chain.polygon_supernet_deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:polygon_supernet_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  def deposits_count(conn, _params) do
    items_count(conn, PolygonSupernetDepositExecute)
  end

  defp items_count(conn, module) do
    count = Chain.get_table_rows_total_count(module, api?: true)

    conn
    |> put_status(200)
    |> render(:polygon_supernet_items_count, %{count: count})
  end
end
