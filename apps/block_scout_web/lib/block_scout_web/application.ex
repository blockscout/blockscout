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

    RateLimitConfigHelper.fetch_config()

    if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Supervisor.start_link([Supervisor.child_spec(HealthEndpoint, [])], opts)
    else
      base_children = [Supervisor.child_spec(Endpoint, [])]
      api_children = setup_and_define_children()
      all_children = base_children ++ api_children

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
      []
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
      [
        # Start the endpoint when the application starts
        {Phoenix.PubSub, name: BlockScoutWeb.PubSub},
        {Absinthe.Subscription, Endpoint},
        {MainPageRealtimeEventHandler, name: MainPageRealtimeEventHandler},
        {RealtimeEventHandler, name: RealtimeEventHandler},
        {SmartContractRealtimeEventHandler, name: SmartContractRealtimeEventHandler},
        {BlocksIndexedCounter, name: BlocksIndexedCounter},
        {InternalTransactionsIndexedCounter, name: InternalTransactionsIndexedCounter},
        {EventHandlersMetrics, []},
        {ChainMetrics, []},
        Hammer.child_for_supervisor()
      ]
    end
  end
end
