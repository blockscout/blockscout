defmodule BlockScoutWeb.API.V2.OptimismController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def output_roots(conn, params) do
    {roots, next_page} =
      params
      |> paging_options()
      |> Chain.list_output_roots()
      |> split_list_by_page()

    total = Chain.output_roots_total_count()

    next_page_params = next_page_params(next_page, roots, params)

    conn
    |> put_status(200)
    |> render(:output_roots, %{
      roots: roots,
      total: total,
      next_page_params: next_page_params
    })
  end

  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Chain.list_optimism_withdrawals()
      |> split_list_by_page()

    total = Chain.optimism_withdrawals_total_count()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:optimism_withdrawals, %{
      withdrawals: withdrawals,
      total: total,
      next_page_params: next_page_params
    })
  end
end
