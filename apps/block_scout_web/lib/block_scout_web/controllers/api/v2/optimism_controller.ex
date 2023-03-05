defmodule BlockScoutWeb.API.V2.OptimismController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain
  alias Explorer.Chain.{OptimismOutputRoot, OptimismTxnBatch, OptimismWithdrawal}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def txn_batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Chain.list_txn_batches()
      |> split_list_by_page()

    total = Chain.get_table_rows_total_count(OptimismTxnBatch)

    next_page_params = next_page_params(next_page, batches, params)

    conn
    |> put_status(200)
    |> render(:optimism_txn_batches, %{
      batches: batches,
      total: total,
      next_page_params: next_page_params
    })
  end

  def output_roots(conn, params) do
    {roots, next_page} =
      params
      |> paging_options()
      |> Chain.list_output_roots()
      |> split_list_by_page()

    total = Chain.get_table_rows_total_count(OptimismOutputRoot)

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

    total = Chain.get_table_rows_total_count(OptimismWithdrawal)

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
