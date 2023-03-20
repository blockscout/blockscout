defmodule EventStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Explorer.Celo.Telemetry.MetricsCollector, as: CeloPrometheusCollector
  alias EventStream.{ContractEventStream, Endpoint, Metrics}
  alias EventStream.Publisher.Beanstalkd, as: BeanstalkdPublisher

  def start(_type, _args) do
    children =
      [
        Endpoint,
        {CeloPrometheusCollector, metrics: [Metrics.metrics()]},
        Supervisor.child_spec({Phoenix.PubSub, name: :chain_pubsub}, id: :chain_pubsub),
        Supervisor.child_spec({Phoenix.PubSub, name: EventStream.PubSub}, id: EventStream.PubSub),
        {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
        # listen for chain events and publish through registry
        {Explorer.Chain.Events.Listener, %{event_source: Explorer.Chain.Events.PubSubSource}},
        {ContractEventStream, %{}}
        # Start a worker by calling: EventStream.Worker.start_link(arg)
        # {EventStream.Worker, arg}
      ]
      |> beanstalkd_process(Application.get_env(:blockscout, :environment))
      |> cluster_process(Application.get_env(:blockscout, :environment))

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventStream.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  def beanstalkd_process(acc, _env) do
    beanstalk_config = Application.get_env(:event_stream, :beanstalkd)

    if Keyword.get(beanstalk_config, :enabled, false) do
      host = Keyword.fetch!(beanstalk_config, :host)
      port = Keyword.get(beanstalk_config, :port, 11300)
      tube = Keyword.get(beanstalk_config, :tube, "default")

      [{BeanstalkdPublisher, [host: host, port: port, tube: tube]} | acc]
    else
      acc
    end
  end

  def cluster_process(acc, :prod) do
    topologies = Application.get_env(:libcluster, :topologies)

    [{Cluster.Supervisor, [topologies, [name: EventStream.ClusterSupervisor]]} | acc]
  end

  def cluster_process(acc, _environment), do: acc
end
