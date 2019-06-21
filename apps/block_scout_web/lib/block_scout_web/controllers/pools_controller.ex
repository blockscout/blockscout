defmodule BlockScoutWeb.PoolsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.PoolsView
  alias Explorer.Chain
  alias Explorer.Chain.BlockNumberCache
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.EpochCounter
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  def validators(conn, params) do
    render_template(:validator, conn, params)
  end

  def active_pools(conn, params) do
    render_template(:active, conn, params)
  end

  def inactive_pools(conn, params) do
    render_template(:inactive, conn, params)
  end

  defp render_template(filter, conn, %{"type" => "JSON"} = params) do
    [paging_options: options] = paging_options(params)

    last_index =
      params
      |> Map.get("position", "0")
      |> String.to_integer()

    pools_plus_one = Chain.staking_pools(filter, options)

    pools_with_index =
      pools_plus_one
      |> Enum.with_index(last_index + 1)
      |> Enum.map(fn {pool, index} ->
        Map.put(pool, :position, index)
      end)

    {pools, next_page} = split_list_by_page(pools_with_index)

    next_page_path =
      case next_page_params(next_page, pools, params) do
        nil ->
          nil

        next_page_params ->
          next_page_path(filter, conn, Map.delete(next_page_params, "type"))
      end

    average_block_time = AverageBlockTime.average_block_time()

    items =
      pools
      |> Enum.map(fn pool ->
        View.render_to_string(
          PoolsView,
          "_rows.html",
          pool: pool,
          average_block_time: average_block_time,
          pools_type: filter
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  defp render_template(filter, conn, _) do
    epoch_number = EpochCounter.epoch_number() || 0
    epoch_end_block = EpochCounter.epoch_end_block() || 0
    block_number = BlockNumberCache.max_number()
    average_block_time = AverageBlockTime.average_block_time()

    options = [
      pools_type: filter,
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      current_path: current_path(conn),
      average_block_time: average_block_time
    ]

    render(conn, "index.html", options)
  end

  defp next_page_path(:validator, conn, params) do
    validators_path(conn, :validators, params)
  end

  defp next_page_path(:active, conn, params) do
    active_pools_path(conn, :active_pools, params)
  end

  defp next_page_path(:inactive, conn, params) do
    inactive_pools_path(conn, :inactive_pools, params)
  end
end
