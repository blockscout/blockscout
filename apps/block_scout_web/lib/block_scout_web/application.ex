defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.Counters.{BlocksIndexedCounter, InternalTransactionsIndexedCounter}
  alias BlockScoutWeb.{Endpoint, Prometheus}
  alias BlockScoutWeb.{RealtimeEventHandler, StakingEventHandler}

  def start(_type, _args) do
    import Supervisor

    Prometheus.Instrumenter.setup()
    Prometheus.Exporter.setup()

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
    children = [
      # Start the endpoint when the application starts
      {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
      child_spec(Endpoint, []),
      {Absinthe.Subscription, Endpoint},
      {RealtimeEventHandler, name: RealtimeEventHandler},
      {StakingEventHandler, name: StakingEventHandler},
      {BlocksIndexedCounter, name: BlocksIndexedCounter},
      {InternalTransactionsIndexedCounter, name: InternalTransactionsIndexedCounter}
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
