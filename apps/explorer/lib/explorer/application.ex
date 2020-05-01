defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.Admin

  alias Explorer.Chain.Cache.{
    Accounts,
    AddressSum,
    AddressSumMinusBurnt,
    BlockCount,
    BlockNumber,
    Blocks,
    NetVersion,
    PendingTransactions,
    TransactionCount,
    Transactions,
    Uncles
  }

  alias Explorer.Chain.Supply.RSK

  alias Explorer.Market.MarketHistoryCache
  alias Explorer.Repo.PrometheusLogger

  @impl Application
  def start(_type, _args) do
    PrometheusLogger.setup()

    :telemetry.attach(
      "prometheus-ecto",
      [:explorer, :repo, :query],
      &PrometheusLogger.handle_event/4,
      %{}
    )

    # Children to start in all environments
    base_children = [
      Explorer.Repo,
      Supervisor.Spec.worker(SpandexDatadog.ApiServer, [datadog_opts()]),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.HistoryTaskSupervisor}, id: Explorer.HistoryTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.GenesisDataTaskSupervisor}, id: GenesisDataTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      Explorer.SmartContract.SolcDownloader,
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]},
      TransactionCount,
      AddressSum,
      AddressSumMinusBurnt,
      BlockCount,
      Blocks,
      NetVersion,
      BlockNumber,
      con_cache_child_spec(MarketHistoryCache.cache_name()),
      con_cache_child_spec(RSK.cache_name(), ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(30)),
      Transactions,
      Accounts,
      PendingTransactions,
      Uncles
    ]

    children = base_children ++ configurable_children()

    opts = [strategy: :one_for_one, name: Explorer.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp configurable_children do
    [
      configure(Explorer.ExchangeRates),
      configure(Explorer.ChainSpec.GenesisData),
      configure(Explorer.KnownTokens),
      configure(Explorer.Market.History.Cataloger),
      configure(Explorer.Chain.Transaction.History.Historian),
      configure(Explorer.Chain.Events.Listener),
      configure(Explorer.Counters.AddressesWithBalanceCounter),
      configure(Explorer.Counters.AddressesCounter),
      configure(Explorer.Counters.AverageBlockTime),
      configure(Explorer.Validator.MetadataProcessor),
      configure(Explorer.Staking.EpochCounter)
    ]
    |> List.flatten()
  end

  defp should_start?(process) do
    Application.get_env(:explorer, process, [])[:enabled] == true
  end

  defp configure(process) do
    if should_start?(process) do
      process
    else
      []
    end
  end

  defp datadog_opts do
    [
      host: System.get_env("DATADOG_HOST") || "localhost",
      port: System.get_env("DATADOG_PORT") || 8126,
      batch_size: System.get_env("SPANDEX_BATCH_SIZE") || 100,
      sync_threshold: System.get_env("SPANDEX_SYNC_THRESHOLD") || 100,
      http: HTTPoison
    ]
  end

  defp con_cache_child_spec(name, params \\ [ttl_check_interval: false]) do
    params = Keyword.put(params, :name, name)

    Supervisor.child_spec(
      {
        ConCache,
        params
      },
      id: {ConCache, name}
    )
  end
end
