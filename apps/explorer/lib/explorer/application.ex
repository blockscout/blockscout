defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.{Admin, TokenTransferTokenIdMigration}

  alias Explorer.Chain.Cache.{
    Accounts,
    AddressSum,
    AddressSumMinusBurnt,
    Block,
    BlockNumber,
    Blocks,
    GasPriceOracle,
    GasUsage,
    MinMissingBlockNumber,
    NetVersion,
    Transaction,
    Transactions,
    TransactionsApiV2,
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
      Explorer.Repo.Account,
      Explorer.Vault,
      Supervisor.child_spec({SpandexDatadog.ApiServer, datadog_opts()}, id: SpandexDatadog.ApiServer),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.HistoryTaskSupervisor}, id: Explorer.HistoryTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.GenesisDataTaskSupervisor}, id: GenesisDataTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      Explorer.SmartContract.SolcDownloader,
      Explorer.SmartContract.VyperDownloader,
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]},
      Transaction,
      AddressSum,
      AddressSumMinusBurnt,
      Block,
      Blocks,
      GasPriceOracle,
      GasUsage,
      NetVersion,
      BlockNumber,
      con_cache_child_spec(MarketHistoryCache.cache_name()),
      con_cache_child_spec(RSK.cache_name(), ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(30)),
      Transactions,
      TransactionsApiV2,
      Accounts,
      Uncles,
      {Redix, redix_opts()}
    ]

    children = base_children ++ configurable_children()

    opts = [strategy: :one_for_one, name: Explorer.Supervisor, max_restarts: 1_000]

    Supervisor.start_link(children, opts)
  end

  defp configurable_children do
    [
      configure(Explorer.ExchangeRates),
      configure(Explorer.ExchangeRates.TokenExchangeRates),
      configure(Explorer.ChainSpec.GenesisData),
      configure(Explorer.Market.History.Cataloger),
      configure(Explorer.Chain.Cache.ContractsCounter),
      configure(Explorer.Chain.Cache.NewContractsCounter),
      configure(Explorer.Chain.Cache.VerifiedContractsCounter),
      configure(Explorer.Chain.Cache.NewVerifiedContractsCounter),
      configure(Explorer.Chain.Cache.TransactionActionTokensData),
      configure(Explorer.Chain.Cache.TransactionActionUniswapPools),
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
      configure(Explorer.Counters.ContractsCounter),
      configure(Explorer.Counters.NewContractsCounter),
      configure(Explorer.Counters.VerifiedContractsCounter),
      configure(Explorer.Counters.NewVerifiedContractsCounter),
      configure(Explorer.Counters.AverageBlockTime),
      configure(Explorer.Counters.Bridge),
      configure(Explorer.Validator.MetadataProcessor),
      configure(Explorer.Tags.AddressTag.Cataloger),
      configure(MinMissingBlockNumber),
      configure(TokenTransferTokenIdMigration.Supervisor),
      configure(Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand),
      configure(Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand),
      sc_microservice_configure(Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)
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

  defp sc_microservice_configure(process) do
    config = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, [])

    if config[:enabled] && config[:type] == "eth_bytecode_db" do
      process
    else
      []
    end
  end

  defp datadog_port do
    Application.get_env(:explorer, :datadog)[:port]
  end

  defp spandex_batch_size do
    Application.get_env(:explorer, :spandex)[:batch_size]
  end

  defp spandex_sync_threshold do
    Application.get_env(:explorer, :spandex)[:sync_threshold]
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

  defp redix_opts do
    {System.get_env("ACCOUNT_REDIS_URL") || "redis://127.0.0.1:6379", [name: :redix]}
  end
end
