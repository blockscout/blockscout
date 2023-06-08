defmodule BlockScoutWeb.API.V2.OptimismController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain
  alias Explorer.Chain.{OptimismDeposit, OptimismOutputRoot, OptimismTxnBatch, OptimismWithdrawal}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def txn_batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Chain.list_txn_batches()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, params)

    conn
    |> put_status(200)
    |> render(:optimism_txn_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  def txn_batches_count(conn, _params) do
    items_count(conn, OptimismTxnBatch)
  end

  def output_roots(conn, params) do
    {roots, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Chain.list_output_roots()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, roots, params)

    conn
    |> put_status(200)
    |> render(:optimism_output_roots, %{
      roots: roots,
      next_page_params: next_page_params
    })
  end

  def output_roots_count(conn, _params) do
    items_count(conn, OptimismOutputRoot)
  end

  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Chain.list_optimism_deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:optimism_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  def deposits_count(conn, _params) do
    items_count(conn, OptimismDeposit)
  end

  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Chain.list_optimism_withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:optimism_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  def withdrawals_count(conn, _params) do
    items_count(conn, OptimismWithdrawal)
  end

  defp items_count(conn, module) do
    count = Chain.get_table_rows_total_count(module, api?: true)

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end
end
