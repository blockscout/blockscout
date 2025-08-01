defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application
  use Utils.CompileTimeEnvHelper, disable_api?: [:block_scout_web, :disable_api?]

  alias BlockScoutWeb.{Endpoint, HealthEndpoint, RateLimit.Hammer}
  alias BlockScoutWeb.Utility.RateLimitConfigHelper

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: BlockScoutWeb.Supervisor, max_restarts: 1_000]

    if not @disable_api? do
      RateLimitConfigHelper.store_rate_limit_config()
    end

    if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Supervisor.start_link([Supervisor.child_spec(HealthEndpoint, [])], opts)
    else
      # Endpoint must be the last child in the supervision tree
      # since it must be started after all of the other processes
      # (to be sure that application is ready to handle traffic)
      # and stopped before them for the same reason.
      # However, some processes may depend on Endpoint
      # so they need to be started after.
      base_children = [Supervisor.child_spec(Endpoint, [])]
      {first_api_children, last_api_children} = setup_and_define_children()
      all_children = first_api_children ++ base_children ++ last_api_children

      Supervisor.start_link(all_children, opts)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  if @disable_api? do
    defp setup_and_define_children do
      BlockScoutWeb.Prometheus.Exporter.setup()
      {[], []}
    end
  else
    defp setup_and_define_children do
      alias BlockScoutWeb.API.APILogger
      alias BlockScoutWeb.Counters.{BlocksIndexedCounter, InternalTransactionsIndexedCounter}
      alias BlockScoutWeb.Prometheus.{Exporter, PhoenixInstrumenter, PublicExporter}
      alias BlockScoutWeb.{MainPageRealtimeEventHandler, RealtimeEventHandler, SmartContractRealtimeEventHandler}
      alias BlockScoutWeb.Utility.EventHandlersMetrics
      alias Explorer.Chain.Metrics, as: ChainMetrics

      PhoenixInstrumenter.setup()
      Exporter.setup()
      PublicExporter.setup()

      APILogger.message(
        "Current API rate limit by key #{inspect(Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_key])} reqs/sec"
      )

      APILogger.message(
        "Current API rate limit by IP #{inspect(Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_ip])} reqs/sec"
      )

      # Define workers and child supervisors to be supervised
      {
        [
          {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
          {MainPageRealtimeEventHandler, name: MainPageRealtimeEventHandler},
          {RealtimeEventHandler, name: RealtimeEventHandler},
          {SmartContractRealtimeEventHandler, name: SmartContractRealtimeEventHandler},
          {BlocksIndexedCounter, name: BlocksIndexedCounter},
          {InternalTransactionsIndexedCounter, name: InternalTransactionsIndexedCounter},
          {EventHandlersMetrics, []},
          {ChainMetrics, []},
          Hammer.child_for_supervisor()
        ],
        [
          {Absinthe.Subscription, Endpoint}
        ]
      }
    end
  end
end
