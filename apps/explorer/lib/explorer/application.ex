defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.Admin

  alias Explorer.Chain.Cache.{
    Accounts,
    BackgroundMigrations,
    BlockNumber,
    Blocks,
    ChainId,
    GasPriceOracle,
    MinMissingBlockNumber,
    StateChanges,
    Transactions,
    TransactionsApiV2,
    Uncles
  }

  alias Explorer.Chain.Cache.Counters.{
    AddressesCoinBalanceSum,
    AddressesCoinBalanceSumMinusBurnt,
    AddressTabsElementsCount,
    BlocksCount,
    GasUsageSum,
    PendingBlockOperationCount,
    TransactionsCount
  }

  alias Explorer.Chain.Optimism.InteropMessage, as: OptimismInteropMessage
  alias Explorer.Chain.Supply.RSK

  alias Explorer.Market.MarketHistoryCache
  alias Explorer.MicroserviceInterfaces.MultichainSearch
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
      Explorer.Chain.Health.Monitor,
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]},
      Accounts,
      AddressesCoinBalanceSum,
      AddressesCoinBalanceSumMinusBurnt,
      BackgroundMigrations,
      BlocksCount,
      BlockNumber,
      Blocks,
      ChainId,
      GasPriceOracle,
      GasUsageSum,
      PendingBlockOperationCount,
      TransactionsCount,
      StateChanges,
      Transactions,
      TransactionsApiV2,
      Uncles,
      AddressTabsElementsCount,
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
        configure_mode_dependent_process(Explorer.Market.Fetcher.Coin, :api),
        configure_mode_dependent_process(Explorer.Market.Fetcher.Token, :indexer),
        configure_mode_dependent_process(Explorer.Market.Fetcher.History, :indexer),
        configure(Explorer.ChainSpec.GenesisData),
        configure(Explorer.Chain.Cache.Counters.ContractsCount),
        configure(Explorer.Chain.Cache.Counters.NewContractsCount),
        configure(Explorer.Chain.Cache.Counters.VerifiedContractsCount),
        configure(Explorer.Chain.Cache.Counters.NewVerifiedContractsCount),
        configure(Explorer.Chain.Cache.TransactionActionTokensData),
        configure(Explorer.Chain.Cache.TransactionActionUniswapPools),
        configure(Explorer.Chain.Cache.Counters.WithdrawalsSum),
        configure(Explorer.Chain.Transaction.History.Historian),
        configure(Explorer.Chain.Events.Listener),
        configure(Explorer.Chain.Cache.Counters.AddressesCount),
        configure(Explorer.Chain.Cache.Counters.AddressTransactionsCount),
        configure(Explorer.Chain.Cache.Counters.AddressTokenTransfersCount),
        configure(Explorer.Chain.Cache.Counters.AddressTransactionsGasUsageSum),
        configure(Explorer.Chain.Cache.Counters.AddressTokensUsdSum),
        configure(Explorer.Chain.Cache.Counters.TokenHoldersCount),
        configure(Explorer.Chain.Cache.Counters.TokenTransfersCount),
        configure(Explorer.Chain.Cache.Counters.BlockBurntFeeCount),
        configure(Explorer.Chain.Cache.Counters.BlockPriorityFeeCount),
        configure(Explorer.Chain.Cache.Counters.AverageBlockTime),
        configure(Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount),
        configure(Explorer.Chain.Cache.Counters.NewPendingTransactionsCount),
        configure(Explorer.Chain.Cache.Counters.Transactions24hCount),
        configure(Explorer.Validator.MetadataProcessor),
        configure(Explorer.Tags.AddressTag.Cataloger),
        configure(Explorer.SmartContract.CertifiedSmartContractCataloger),
        configure(MinMissingBlockNumber),
        configure(Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand),
        configure(Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand),
        configure(Explorer.TokenInstanceOwnerAddressMigration.Supervisor),
        configure_sc_microservice(Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand),
        configure(Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCount),
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
        configure(Explorer.Migrator.SmartContractLanguage),
        configure(Explorer.Migrator.SanitizeErc1155TokenBalancesWithoutTokenIds),
        Explorer.Migrator.BackfillMultichainSearchDB
        |> configure_mode_dependent_process(:indexer)
        |> configure_multichain_search_microservice(),
        configure_mode_dependent_process(Explorer.Migrator.ArbitrumDaRecordsNormalization, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.ShrinkInternalTransactions, :indexer),
        configure_chain_type_dependent_process(Explorer.Chain.Cache.Counters.Blackfort.ValidatorsCount, :blackfort),
        configure_chain_type_dependent_process(Explorer.Chain.Cache.Counters.Stability.ValidatorsCount, :stability),
        configure_chain_type_dependent_process(Explorer.Chain.Cache.LatestL1BlockNumber, [
          :optimism,
          :polygon_edge,
          :polygon_zkevm,
          :scroll,
          :shibarium
        ]),
        configure_chain_type_dependent_con_cache(),
        Explorer.Migrator.SanitizeDuplicatedLogIndexLogs
        |> configure()
        |> configure_chain_type_dependent_process([
          :polygon_zkevm,
          :rsk,
          :filecoin
        ]),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeMissingTokenBalances, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeReplacedTransactions, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeVerifiedAddresses, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.SanitizeEmptyContractCodeAddresses, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus, :indexer),
        configure_mode_dependent_process(Explorer.Migrator.ReindexDuplicatedInternalTransactions, :indexer),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedIndex,
          :indexer
        ),
        configure_mode_dependent_process(Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockHashIndex, :indexer),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashTransactionHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropLogsIndexIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberAscLogIndexAscIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersFromAddressHashTransactionHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersToAddressHashTransactionHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersTokenContractAddressHashTransactionHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropAddressesVerifiedIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedTransactionsCountDescHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateSmartContractsLanguageIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsFromAddressHashWithPendingIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsToAddressHashWithPendingIndex,
          :indexer
        ),
        configure_mode_dependent_process(Explorer.Migrator.BackfillMetadataURL, :indexer),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateLogsDepositsWithdrawalsIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountDescPartialIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex,
          :indexer
        ),
        configure_mode_dependent_process(
          Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockHashTransactionIndexIndexUniqueIndex,
          :indexer
        ),
        Explorer.Migrator.RefetchContractCodes |> configure() |> configure_chain_type_dependent_process(:zksync),
        configure(Explorer.Chain.Fetcher.AddressesBlacklist),
        Explorer.Migrator.SwitchPendingOperations,
        configure_mode_dependent_process(Explorer.Utility.RateLimiter, :api)
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

  defp configure_chain_type_dependent_con_cache do
    case Application.get_env(:explorer, :chain_type) do
      :optimism ->
        [
          con_cache_child_spec(OptimismInteropMessage.interop_instance_api_url_to_public_key_cache()),
          con_cache_child_spec(OptimismInteropMessage.interop_chain_id_to_instance_info_cache())
        ]

      _ ->
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

  defp configure_sc_microservice(process) do
    if Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)[:eth_bytecode_db?] do
      process
    else
      []
    end
  end

  defp configure_multichain_search_microservice(process) do
    if MultichainSearch.enabled?() do
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
