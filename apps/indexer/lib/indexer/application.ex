defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias EthereumJSONRPC.Celo.Instrumentation, as: EthRPC
  alias Explorer.Celo.Telemetry.Instrumentation.{Blockchain, Database, FlyPostgres}
  alias Explorer.Celo.Telemetry.MetricsCollector, as: CeloPrometheusCollector

  alias Indexer.Celo.Telemetry.Instrumentation, as: IndexerMetrics
  alias Indexer.Memory

  @impl Application
  def start(_type, _args) do
    memory_monitor_options =
      case Application.get_env(:indexer, :memory_limit) do
        nil -> %{}
        integer when is_integer(integer) -> %{limit: integer}
      end

    memory_monitor_name = Memory.Monitor

    base_children =
      [
        {Memory.Monitor, [memory_monitor_options, [name: memory_monitor_name]]},
        {CeloPrometheusCollector, metrics: [IndexerMetrics, FlyPostgres, Blockchain, EthRPC, Database]},
        {Plug.Cowboy,
         scheme: :http,
         plug: Indexer.Celo.MonitorStack,
         options: [port: Application.get_env(:indexer, :health_check_port)]}
      ]
      |> cluster_process(Application.get_env(:indexer, :environment))

    children =
      if Application.get_env(:indexer, Indexer.Supervisor)[:enabled] do
        Enum.reverse([{Indexer.Supervisor, [%{memory_monitor: memory_monitor_name}]} | base_children])
      else
        base_children
      end

    opts = [
      # If the `Memory.Monitor` dies, it needs all the `Shrinkable`s to re-register, so restart them.
      strategy: :rest_for_one,
      name: Indexer.Application
    ]

    Supervisor.start_link(children, opts)
  end

  def cluster_process(acc, :prod) do
    topologies = Application.get_env(:libcluster, :topologies)

    [{Cluster.Supervisor, [topologies, [name: Indexer.ClusterSupervisor]]} | acc]
  end

  def cluster_process(acc, _environment), do: acc
end
