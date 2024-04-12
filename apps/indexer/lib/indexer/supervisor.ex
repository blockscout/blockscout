defmodule Indexer.Supervisor do
  @moduledoc """
  Supervisor of all indexer worker supervision trees
  """

  use Supervisor

  alias Explorer.Chain.BridgedToken

  alias Indexer.{
    Block,
    BridgedTokens.CalcLpTokensTotalLiquidity,
    BridgedTokens.SetAmbBridgedMetadataForTokens,
    BridgedTokens.SetOmniBridgedMetadataForTokens,
    PendingOpsCleaner,
    PendingTransactionsSanitizer
  }

  alias Indexer.Block.Catchup, as: BlockCatchup
  alias Indexer.Block.Realtime, as: BlockRealtime
  alias Indexer.Fetcher.CoinBalance.Catchup, as: CoinBalanceCatchup
  alias Indexer.Fetcher.CoinBalance.Realtime, as: CoinBalanceRealtime
  alias Indexer.Fetcher.Stability.Validator, as: ValidatorStability
  alias Indexer.Fetcher.TokenInstance.LegacySanitize, as: TokenInstanceLegacySanitize
  alias Indexer.Fetcher.TokenInstance.Realtime, as: TokenInstanceRealtime
  alias Indexer.Fetcher.TokenInstance.Retry, as: TokenInstanceRetry
  alias Indexer.Fetcher.TokenInstance.Sanitize, as: TokenInstanceSanitize
  alias Indexer.Fetcher.TokenInstance.SanitizeERC1155, as: TokenInstanceSanitizeERC1155
  alias Indexer.Fetcher.TokenInstance.SanitizeERC721, as: TokenInstanceSanitizeERC721

  alias Indexer.Fetcher.{
    BlockReward,
    ContractCode,
    EmptyBlocksSanitizer,
    InternalTransaction,
    PendingBlockOperationsSanitizer,
    PendingTransaction,
    ReplacedTransaction,
    RootstockData,
    Token,
    TokenBalance,
    TokenTotalSupplyUpdater,
    TokenUpdater,
    TransactionAction,
    UncleBlock,
    Withdrawal
  }

  alias Indexer.Fetcher.ZkSync.BatchesStatusTracker, as: ZkSyncBatchesStatusTracker
  alias Indexer.Fetcher.ZkSync.TransactionBatch, as: ZkSyncTransactionBatch

  alias Indexer.Temporary.{
    BlocksTransactionsMismatch,
    UncatalogedTokenTransfers,
    UnclesWithoutIndex
  }

  def child_spec([]) do
    child_spec([[]])
  end

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(arguments, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, arguments, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl Supervisor
  def init(%{memory_monitor: memory_monitor}) do
    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    named_arguments =
      :indexer
      |> Application.get_all_env()
      |> Keyword.take(
        ~w(blocks_batch_size blocks_concurrency block_interval json_rpc_named_arguments receipts_batch_size
           receipts_concurrency subscribe_named_arguments realtime_overrides)a
      )
      |> Enum.into(%{})
      |> Map.put(:memory_monitor, memory_monitor)
      |> Map.put_new(:realtime_overrides, %{})

    %{
      block_interval: block_interval,
      realtime_overrides: realtime_overrides,
      subscribe_named_arguments: subscribe_named_arguments
    } = named_arguments

    block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval blocks_concurrency memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Block.Fetcher.new()

    realtime_block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval blocks_concurrency memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Map.merge(Enum.into(realtime_overrides, %{}))
      |> Block.Fetcher.new()

    realtime_subscribe_named_arguments = realtime_overrides[:subscribe_named_arguments] || subscribe_named_arguments

    basic_fetchers =
      [
        # Root fetchers
        {PendingTransaction.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]},

        # Async catchup fetchers
        {UncleBlock.Supervisor, [[block_fetcher: block_fetcher, memory_monitor: memory_monitor]]},
        {InternalTransaction.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {CoinBalanceCatchup.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {CoinBalanceRealtime.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {Token.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {TokenInstanceRealtime.Supervisor, [[memory_monitor: memory_monitor]]},
        {TokenInstanceRetry.Supervisor, [[memory_monitor: memory_monitor]]},
        {TokenInstanceSanitize.Supervisor, [[memory_monitor: memory_monitor]]},
        configure(TokenInstanceLegacySanitize, [[memory_monitor: memory_monitor]]),
        configure(TokenInstanceSanitizeERC721, [[memory_monitor: memory_monitor]]),
        configure(TokenInstanceSanitizeERC1155, [[memory_monitor: memory_monitor]]),
        configure(TransactionAction.Supervisor, [[memory_monitor: memory_monitor]]),
        {ContractCode.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {TokenBalance.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {TokenUpdater.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {ReplacedTransaction.Supervisor, [[memory_monitor: memory_monitor]]},
        {Indexer.Fetcher.RollupL1ReorgMonitor.Supervisor, [[memory_monitor: memory_monitor]]},
        configure(
          Indexer.Fetcher.Optimism.TxnBatch.Supervisor,
          [[memory_monitor: memory_monitor, json_rpc_named_arguments: json_rpc_named_arguments]]
        ),
        configure(Indexer.Fetcher.Optimism.OutputRoot.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.Optimism.Deposit.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(
          Indexer.Fetcher.Optimism.Withdrawal.Supervisor,
          [[memory_monitor: memory_monitor, json_rpc_named_arguments: json_rpc_named_arguments]]
        ),
        configure(Indexer.Fetcher.Optimism.WithdrawalEvent.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.PolygonEdge.Deposit.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.PolygonEdge.DepositExecute.Supervisor, [
          [memory_monitor: memory_monitor, json_rpc_named_arguments: json_rpc_named_arguments]
        ]),
        configure(Indexer.Fetcher.PolygonEdge.Withdrawal.Supervisor, [
          [memory_monitor: memory_monitor, json_rpc_named_arguments: json_rpc_named_arguments]
        ]),
        configure(Indexer.Fetcher.PolygonEdge.WithdrawalExit.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.Shibarium.L2.Supervisor, [
          [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
        ]),
        configure(Indexer.Fetcher.Shibarium.L1.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.PolygonZkevm.BridgeL1.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.PolygonZkevm.BridgeL1Tokens.Supervisor, [[memory_monitor: memory_monitor]]),
        configure(Indexer.Fetcher.PolygonZkevm.BridgeL2.Supervisor, [
          [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
        ]),
        configure(ZkSyncTransactionBatch.Supervisor, [
          [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
        ]),
        configure(ZkSyncBatchesStatusTracker.Supervisor, [
          [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
        ]),
        configure(Indexer.Fetcher.PolygonZkevm.TransactionBatch.Supervisor, [
          [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
        ]),
        {Indexer.Fetcher.Beacon.Blob.Supervisor, [[memory_monitor: memory_monitor]]},

        # Out-of-band fetchers
        {EmptyBlocksSanitizer.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]},
        {PendingTransactionsSanitizer, [[json_rpc_named_arguments: json_rpc_named_arguments]]},
        {TokenTotalSupplyUpdater, [[]]},

        # Temporary workers
        {UncatalogedTokenTransfers.Supervisor, [[]]},
        {UnclesWithoutIndex.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {BlocksTransactionsMismatch.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
        {PendingOpsCleaner, [[], []]},
        {PendingBlockOperationsSanitizer, [[]]},
        {RootstockData.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]},

        # Block fetchers
        configure(BlockRealtime.Supervisor, [
          %{block_fetcher: realtime_block_fetcher, subscribe_named_arguments: realtime_subscribe_named_arguments},
          [name: BlockRealtime.Supervisor]
        ]),
        configure(
          BlockCatchup.Supervisor,
          [
            %{block_fetcher: block_fetcher, block_interval: block_interval, memory_monitor: memory_monitor},
            [name: BlockCatchup.Supervisor]
          ]
        ),
        {Withdrawal.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]}
      ]
      |> List.flatten()

    all_fetchers =
      basic_fetchers
      |> maybe_add_bridged_tokens_fetchers()
      |> add_chain_type_dependent_fetchers()
      |> maybe_add_block_reward_fetcher(
        {BlockReward.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]}
      )

    Supervisor.init(
      all_fetchers,
      strategy: :one_for_one
    )
  end

  defp maybe_add_bridged_tokens_fetchers(basic_fetchers) do
    extended_fetchers =
      if BridgedToken.enabled?() && BridgedToken.necessary_envs_passed?() do
        [{CalcLpTokensTotalLiquidity, [[], []]}, {SetOmniBridgedMetadataForTokens, [[], []]}] ++ basic_fetchers
      else
        basic_fetchers
      end

    amb_bridge_mediators = Application.get_env(:explorer, Explorer.Chain.BridgedToken)[:amb_bridge_mediators]

    if BridgedToken.enabled?() && amb_bridge_mediators && amb_bridge_mediators !== "" do
      [{SetAmbBridgedMetadataForTokens, [[], []]} | extended_fetchers]
    else
      extended_fetchers
    end
  end

  @variants_with_implemented_fetch_beneficiaries [
    EthereumJSONRPC.Besu,
    EthereumJSONRPC.Erigon,
    EthereumJSONRPC.Nethermind
  ]

  defp maybe_add_block_reward_fetcher(
         fetchers,
         {_, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: _memory_monitor]]} = params
       ) do
    case Keyword.fetch(json_rpc_named_arguments, :variant) do
      {:ok, ignored_variant} when ignored_variant not in @variants_with_implemented_fetch_beneficiaries ->
        Application.put_env(:indexer, Indexer.Fetcher.BlockReward.Supervisor, disabled?: true)
        fetchers

      _ ->
        [params | fetchers]
    end
  end

  defp add_chain_type_dependent_fetchers(fetchers) do
    case Application.get_env(:explorer, :chain_type) do
      "stability" ->
        [{ValidatorStability, []} | fetchers]

      _ ->
        fetchers
    end
  end

  defp configure(process, opts) do
    if Application.get_env(:indexer, process)[:enabled] do
      [{process, opts}]
    else
      []
    end
  end
end
