defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application

  require Logger

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.{CampaignBannerCache, LoggerBackend}
  alias BlockScoutWeb.Celo.MetricsCron
  alias BlockScoutWeb.Counters.BlocksIndexedCounter
  alias BlockScoutWeb.{Endpoint, RealtimeEventHandler}

  alias EthereumJSONRPC.Celo.Instrumentation, as: EthRPC
  alias Explorer.Celo.Telemetry.Instrumentation.{Database, FlyPostgres}
  alias Explorer.Celo.Telemetry.MetricsCollector, as: CeloPrometheusCollector

  def start(_type, _args) do
    import Supervisor

    Logger.add_backend(LoggerBackend, level: :error)

    APILogger.message(
      "Current global API rate limit #{inspect(Application.get_env(:block_scout_web, :api_rate_limit)[:global_limit])} reqs/sec"
    )

    APILogger.message(
      "Current API rate limit by key #{inspect(Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_key])} reqs/sec"
    )

    APILogger.message(
      "Current API rate limit by IP #{inspect(Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_ip])} reqs/sec"
    )

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the endpoint when the application starts
        {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
        child_spec(Endpoint, []),
        {Absinthe.Subscription, Endpoint},
        {CeloPrometheusCollector, metrics: [EthRPC.metrics(), Database.metrics(), FlyPostgres.metrics()]},
        {RealtimeEventHandler, name: RealtimeEventHandler},
        {BlocksIndexedCounter, name: BlocksIndexedCounter},
        {CampaignBannerCache, name: CampaignBannerCache}
      ]
      |> cluster_process(Application.get_env(:block_scout_web, :environment))
      |> metrics_processes()

    opts = [strategy: :one_for_one, name: BlockScoutWeb.Supervisor, max_restarts: 1_000]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  def metrics_processes(sibling_processes) do
    sibling_processes ++
      [
        {MetricsCron, [[]]},
        {Task.Supervisor, name: BlockScoutWeb.Celo.MetricsCron.TaskSupervisor}
      ]
  end

  def cluster_process(acc, :prod) do
    topologies = Application.get_env(:libcluster, :topologies)

    [{Cluster.Supervisor, [topologies, [name: BlockScoutWeb.ClusterSupervisor]]} | acc]
  end

  def cluster_process(acc, _environment), do: acc
end
