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
    GasUsage,
    MinMissingBlockNumber,
    NetVersion,
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
      Explorer.Repo.Replica1,
      Supervisor.child_spec({SpandexDatadog.ApiServer, datadog_opts()}, id: SpandexDatadog.ApiServer),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.HistoryTaskSupervisor}, id: Explorer.HistoryTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.GenesisDataTaskSupervisor}, id: GenesisDataTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      Explorer.SmartContract.SolcDownloader,
      Explorer.SmartContract.VyperDownloader,
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]},
      TransactionCount,
      AddressSum,
      AddressSumMinusBurnt,
      BlockCount,
      Blocks,
      GasUsage,
      NetVersion,
      BlockNumber,
      con_cache_child_spec(MarketHistoryCache.cache_name()),
      con_cache_child_spec(RSK.cache_name(), ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(30)),
      Transactions,
      Accounts,
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
      configure(Explorer.Chain.Cache.TokenExchangeRate),
      configure(Explorer.Chain.Transaction.History.Historian),
      configure(Explorer.Chain.Events.Listener),
      configure(Explorer.Counters.AddressesWithBalanceCounter),
      configure(Explorer.Counters.AddressesCounter),
      configure(Explorer.Counters.AddressTransactionsCounter),
      configure(Explorer.Counters.AddressTokenTransfersCounter),
      configure(Explorer.Counters.AddressTransactionsGasUsageCounter),
      configure(Explorer.Counters.AddressTokenUsdSum),
      configure(Explorer.Counters.TokenHoldersCounter),
      configure(Explorer.Counters.TokenTransfersCounter),
      configure(Explorer.Counters.BlockBurnedFeeCounter),
      configure(Explorer.Counters.BlockPriorityFeeCounter),
      configure(Explorer.Counters.AverageBlockTime),
      configure(Explorer.Counters.Bridge),
      configure(Explorer.Validator.MetadataProcessor),
      configure(Explorer.Staking.ContractState),
      configure(MinMissingBlockNumber)
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

  defp datadog_port do
    if System.get_env("DATADOG_PORT") do
      case Integer.parse(System.get_env("DATADOG_PORT")) do
        {integer, ""} -> integer
        _ -> 8126
      end
    else
      8126
    end
  end

  defp spandex_batch_size do
    if System.get_env("SPANDEX_BATCH_SIZE") do
      case Integer.parse(System.get_env("SPANDEX_BATCH_SIZE")) do
        {integer, ""} -> integer
        _ -> 100
      end
    else
      100
    end
  end

  defp spandex_sync_threshold do
    if System.get_env("SPANDEX_SYNC_THRESHOLD") do
      case Integer.parse(System.get_env("SPANDEX_SYNC_THRESHOLD")) do
        {integer, ""} -> integer
        _ -> 100
      end
    else
      100
    end
  end

  defp datadog_opts do
    datadog_port = datadog_port()

    spandex_batch_size = spandex_batch_size()

    spandex_sync_threshold = spandex_sync_threshold()

    [
      host: System.get_env("DATADOG_HOST") || "localhost",
      port: datadog_port,
      batch_size: spandex_batch_size,
      sync_threshold: spandex_sync_threshold,
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
