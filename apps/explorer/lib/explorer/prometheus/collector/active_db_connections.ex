defmodule Explorer.Prometheus.Collector.ActiveDbConnections do
  @moduledoc """
  Custom collector to count number of currently active DB connections.
  """

  use Prometheus.Collector

  alias Prometheus.Model

  def collect_mf(_registry, callback) do
    callback.(create_gauge(:active_db_connections, "Number of active DB connections", get_active_connections_count()))
  end

  def collect_metrics(:active_db_connections, count) do
    Model.gauge_metrics([{count}])
  end

  defp create_gauge(name, help, data) do
    Model.create_mf(name, help, :gauge, __MODULE__, data)
  end

  defp get_active_connections_count do
    :explorer
    |> Application.get_env(:ecto_repos)
    |> Enum.reduce(0, fn repo, count ->
      repo_count =
        case Process.whereis(repo) do
          nil ->
            0

          _pid ->
            # credo:disable-for-next-line Credo.Check.Design.AliasUsage
            repo_params = Ecto.Repo.Registry.lookup(repo)
            pool = repo_params.pid
            pool_size = repo_params.opts[:pool_size]
            ready_connections_count = get_ready_connections_count(pool)

            pool_size - ready_connections_count
        end

      count + repo_count
    end)
  end

  defp get_ready_connections_count(pool) do
    pool
    |> DBConnection.get_connection_metrics()
    |> Enum.reduce(0, fn %{ready_conn_count: ready_conn_count}, acc -> ready_conn_count + acc end)
  end
end
