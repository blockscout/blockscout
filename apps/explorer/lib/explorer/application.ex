defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.Admin

  alias Explorer.Chain.Cache.{
    Accounts,
    AddressesTabsCounters,
    AddressSum,
    AddressSumMinusBurnt,
    BackgroundMigrations,
    Block,
    BlockNumber,
    Blocks,
    GasPriceOracle,
    GasUsage,
    MinMissingBlockNumber,
    NetVersion,
    PendingBlockOperation,
    StateChanges,
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
      Explorer.Vault,
      Supervisor.child_spec({SpandexDatadog.ApiServer, datadog_opts()}, id: SpandexDatadog.ApiServer),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.HistoryTaskSupervisor}, id: Explorer.HistoryTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.GenesisDataTaskSupervisor}, id: GenesisDataTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.LookUpSmartContractSourcesTaskSupervisor},
        id: LookUpSmartContractSourcesTaskSupervisor
      ),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.WETHMigratorSupervisor}, id: WETHMigratorSupervisor),
      Explorer.SmartContract.SolcDownloader,
      Explorer.SmartContract.VyperDownloader,
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]},
      Accounts,
      AddressSum,
      AddressSumMinusBurnt,
      BackgroundMigrations,
      Block,
      BlockNumber,
      Blocks,
      GasPriceOracle,
      GasUsage,
      NetVersion,
      PendingBlockOperation,
      Transaction,
      StateChanges,
      Transactions,
      TransactionsApiV2,
      Uncles,
      AddressesTabsCounters,
      con_cache_child_spec(MarketHistoryCache.cache_name()),
      con_cache_child_spec(RSK.cache_name(), ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(30)),
      {Redix, redix_opts()},
      {Explorer.Utility.MissingRangesManipulator, []},
      {Explorer.Utility.ReplicaAccessibilityManager, []}
    ]

    children = base_children ++ configurable_children()

    opts = [strategy: :one_for_one, name: Explorer.Supervisor, max_restarts: 1_000]

    if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Supervisor.start_link([], opts)
    else
      Supervisor.start_link(children, opts)
    end
  end

  defp configurable_children do
    configurable_children_set =
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
        configure(Explorer.Chain.Cache.WithdrawalsSum),
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
        configure(Explorer.Counters.BlockBurntFeeCounter),
        configure(Explorer.Counters.BlockPriorityFeeCounter),
        configure(Explorer.Counters.AverageBlockTime),
        configure(Explorer.Counters.LastOutputRootSizeCounter),
        configure(Explorer.Counters.FreshPendingTransactionsCounter),
        configure(Explorer.Counters.Transactions24hStats),
        configure(Explorer.Validator.MetadataProcessor),
        configure(Explorer.Tags.AddressTag.Cataloger),
        configure(Explorer.SmartContract.CertifiedSmartContractCataloger),
        configure(MinMissingBlockNumber),
        configure(Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand),
        configure(Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand),
        configure(Explorer.TokenInstanceOwnerAddressMigration.Supervisor),
        sc_microservice_configure(Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand),
        configure(Explorer.Chain.Cache.RootstockLockedBTC),
        configure(Explorer.Chain.Cache.OptimismFinalizationPeriod),
        configure(Explorer.Migrator.TransactionsDenormalization),
        configure(Explorer.Migrator.AddressCurrentTokenBalanceTokenType),
        configure(Explorer.Migrator.AddressTokenBalanceTokenType),
        configure(Explorer.Migrator.SanitizeMissingBlockRanges),
        configure(Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers),
        configure(Explorer.Migrator.TokenTransferTokenType),
        configure(Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers),
        configure(Explorer.Migrator.TransactionBlockConsensus),
        configure(Explorer.Migrator.TokenTransferBlockConsensus),
        configure(Explorer.Migrator.RestoreOmittedWETHTransfers),
        configure(Explorer.Migrator.FilecoinPendingAddressOperations),
        configure_mode_dependent_process(Explorer.Migrator.ShrinkInternalTransactions, :indexer),
        configure_chain_type_dependent_process(Explorer.Chain.Cache.BlackfortValidatorsCounters, :blackfort),
        configure_chain_type_dependent_process(Explorer.Chain.Cache.StabilityValidatorsCounters, :stability),
        Explorer.Migrator.SanitizeDuplicatedLogIndexLogs
        |> configure()
        |> configure_chain_type_dependent_process([
          :polygon_zkevm,
          :rsk,
          :filecoin
        ]),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeMissingTokenBalances, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeReplacedTransactions, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus, :indexer),
        Explorer.Migrator.RefetchContractCodes |> configure() |> configure_chain_type_dependent_process(:zksync)
      ]
      |> List.flatten()

    repos_by_chain_type() ++ account_repo() ++ mud_repo() ++ configurable_children_set
  end

  defp repos_by_chain_type do
    if Mix.env() == :test do
      [
        Explorer.Repo.Arbitrum,
        Explorer.Repo.Beacon,
        Explorer.Repo.Blackfort,
        Explorer.Repo.BridgedTokens,
        Explorer.Repo.Celo,
        Explorer.Repo.Filecoin,
        Explorer.Repo.Optimism,
        Explorer.Repo.PolygonEdge,
        Explorer.Repo.PolygonZkevm,
        Explorer.Repo.RSK,
        Explorer.Repo.Scroll,
        Explorer.Repo.Shibarium,
        Explorer.Repo.ShrunkInternalTransactions,
        Explorer.Repo.Stability,
        Explorer.Repo.Suave,
        Explorer.Repo.Zilliqa,
        Explorer.Repo.ZkSync
      ]
    else
      []
    end
  end

  defp account_repo do
    if Application.get_env(:explorer, Explorer.Account)[:enabled] || Mix.env() == :test do
      [Explorer.Repo.Account]
    else
      []
    end
  end

  defp mud_repo do
    if Application.get_env(:explorer, Explorer.Chain.Mud)[:enabled] || Mix.env() == :test do
      [Explorer.Repo.Mud]
    else
      []
    end
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

  defp configure_chain_type_dependent_process(process, chain_types) when is_list(chain_types) do
    if Application.get_env(:explorer, :chain_type) in chain_types do
      process
    else
      []
    end
  end

  defp configure_chain_type_dependent_process(process, chain_type) do
    if Application.get_env(:explorer, :chain_type) == chain_type do
      process
    else
      []
    end
  end

  defp configure_mode_dependent_process(process, mode) do
    if should_start?(process) and Application.get_env(:explorer, :mode) in [mode, :all] do
      process
    else
      []
    end
  end

  defp sc_microservice_configure(process) do
    if Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)[:eth_bytecode_db?] do
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
