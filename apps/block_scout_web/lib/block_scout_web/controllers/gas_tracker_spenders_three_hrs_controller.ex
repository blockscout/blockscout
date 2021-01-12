defmodule BlockScoutWeb.GasTrackerSpendersThreeHrsController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{ChainController, GasTrackerView}
  alias Explorer.{Chain, PagingOptions}
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    three_hours_before = DateTime.utc_now() |> DateTime.add(-10800, :second)

    gas_spenders =
      three_hours_before
      |> Chain.list_top_gas_spenders(params |> paging_options())

    all_items_params = [
      paging_options: %PagingOptions{}
    ]

    gas_spenders_all =
      three_hours_before
      |> Chain.list_top_gas_consumers(all_items_params)

    total_gas_spent_in_period = Chain.total_gas(gas_spenders_all)

    {gas_spenders_page, next_page} = split_list_by_page(gas_spenders)

    next_page_path =
      case next_page_params(next_page, gas_spenders_page, params) do
        nil ->
          nil

        next_page_params ->
          gas_tracker_consumers_3hrs_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
      end

    items_count_str = Map.get(params, "items_count")

    items_count =
      if items_count_str do
        {items_count, _} = Integer.parse(items_count_str)
        items_count
      else
        0
      end

    items =
      gas_spenders_page
      |> Enum.with_index(1)
      |> Enum.map(fn {gas_consumer, index} ->
        View.render_to_string(
          GasTrackerView,
          "_tile.html",
          gas_consumer: gas_consumer,
          total_gas_in_period: total_gas_spent_in_period,
          index: items_count + index
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

  def index(conn, _params) do
    transaction_stats = ChainController.get_transaction_stats()
    total_gas_usage = Chain.total_gas_usage()

    chart_data_paths = %{
      gas_usage: gas_usage_history_chart_path(conn, :show)
    }

    chart_config = Application.get_env(:block_scout_web, :gas_usage_chart_config, %{})

    render(conn, "index.html",
      current_path: current_path(conn),
      transaction_stats: transaction_stats,
      total_gas_usage: total_gas_usage,
      conn: conn,
      chart_data_paths: chart_data_paths,
      chart_config_json: Jason.encode!(chart_config)
    )
  end
end
