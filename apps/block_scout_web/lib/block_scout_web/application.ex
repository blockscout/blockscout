defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application

  alias BlockScoutWeb.Counters.BlocksIndexedCounter
  alias BlockScoutWeb.{Endpoint, Prometheus}
  alias BlockScoutWeb.{RealtimeEventHandler, StakingEventHandler}

  def start(_type, _args) do
    import Supervisor

    Prometheus.Instrumenter.setup()
    Prometheus.Exporter.setup()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
      child_spec(Endpoint, []),
      {Absinthe.Subscription, Endpoint},
      {RealtimeEventHandler, name: RealtimeEventHandler},
      {StakingEventHandler, name: StakingEventHandler},
      {BlocksIndexedCounter, name: BlocksIndexedCounter},
      {Guardian.DB.Token.SweeperServer, []}
    ]

    opts = [strategy: :one_for_one, name: BlockScoutWeb.Supervisor, max_restarts: 1_000]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
