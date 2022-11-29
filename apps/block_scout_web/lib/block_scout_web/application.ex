defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application

  require Logger

  alias BlockScoutWeb.{CampaignBannerCache, LoggerBackend}
  alias BlockScoutWeb.Counters.BlocksIndexedCounter
  alias BlockScoutWeb.{Endpoint, Prometheus}
  alias BlockScoutWeb.RealtimeEventHandler
  alias Prometheus.{Exporter, GenericInstrumenter}

  def start(_type, _args) do
    import Supervisor

    Exporter.setup()
    GenericInstrumenter.setup()
    PrometheusPhx.setup()
    Logger.add_backend(LoggerBackend, level: :error)

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the endpoint when the application starts
        {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
        child_spec(Endpoint, []),
        {Absinthe.Subscription, Endpoint},
        {RealtimeEventHandler, name: RealtimeEventHandler},
        {BlocksIndexedCounter, name: BlocksIndexedCounter},
        {CampaignBannerCache, name: CampaignBannerCache}
      ]
      |> cluster_process(Application.get_env(:block_scout_web, :environment))

    opts = [strategy: :one_for_one, name: BlockScoutWeb.Supervisor, max_restarts: 1_000]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  def cluster_process(acc, :prod) do
    topologies = Application.get_env(:libcluster, :topologies)

    [{Cluster.Supervisor, [topologies, [name: BlockScoutWeb.ClusterSupervisor]]} | acc]
  end

  def cluster_process(acc, _environment), do: acc
end
