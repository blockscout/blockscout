defmodule BlockScoutWeb.GasTrackerController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.AccessHelpers
  alias Explorer.Chain.Cache.GasUsage

  def index(conn, params) do
    case AccessHelpers.gas_tracker_restricted_access?(params) do
      {:ok, false} ->
        transaction_stats = Helper.get_transaction_stats()
        total_gas_usage = GasUsage.total()

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

      _ ->
        not_found(conn)
    end
  end
end
