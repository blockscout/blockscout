defmodule Explorer.Chain.Import.Stage.BlockReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.BlockRelated`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @default_runners [
    Runner.Transaction.Forks,
    Runner.Logs,
    Runner.Tokens,
    Runner.TokenInstances,
    Runner.TransactionActions,
    Runner.Withdrawals
  ]

  @extra_runners_by_chain_type %{
    optimism: [
      Runner.Optimism.FrameSequences,
      Runner.Optimism.FrameSequenceBlobs,
      Runner.Optimism.TxnBatches,
      Runner.Optimism.OutputRoots,
      Runner.Optimism.DisputeGames,
      Runner.Optimism.Deposits,
      Runner.Optimism.Withdrawals,
      Runner.Optimism.WithdrawalEvents
    ],
    polygon_edge: [
      Runner.PolygonEdge.Deposits,
      Runner.PolygonEdge.DepositExecutes,
      Runner.PolygonEdge.Withdrawals,
      Runner.PolygonEdge.WithdrawalExits
    ],
    polygon_zkevm: [
      Runner.PolygonZkevm.LifecycleTransactions,
      Runner.PolygonZkevm.TransactionBatches,
      Runner.PolygonZkevm.BatchTransactions,
      Runner.PolygonZkevm.BridgeL1Tokens,
      Runner.PolygonZkevm.BridgeOperations
    ],
    zksync: [
      Runner.ZkSync.LifecycleTransactions,
      Runner.ZkSync.TransactionBatches,
      Runner.ZkSync.BatchTransactions,
      Runner.ZkSync.BatchBlocks
    ],
    shibarium: [
      Runner.Shibarium.BridgeOperations
    ],
    ethereum: [
      Runner.Beacon.BlobTransactions
    ],
    arbitrum: [
      Runner.Arbitrum.Messages,
      Runner.Arbitrum.LifecycleTransactions,
      Runner.Arbitrum.L1Executions,
      Runner.Arbitrum.L1Batches,
      Runner.Arbitrum.BatchBlocks,
      Runner.Arbitrum.BatchTransactions,
      Runner.Arbitrum.DaMultiPurposeRecords
    ],
    celo: [
      Runner.Celo.ValidatorGroupVotes,
      Runner.Celo.ElectionRewards,
      Runner.Celo.EpochRewards
    ],
    zilliqa: [
      Runner.Zilliqa.AggregateQuorumCertificates,
      Runner.Zilliqa.NestedQuorumCertificates,
      Runner.Zilliqa.QuorumCertificates
    ]
  }

  @impl Stage
  def runners do
    chain_type = Application.get_env(:explorer, :chain_type)
    chain_type_runners = Map.get(@extra_runners_by_chain_type, chain_type, [])

    @default_runners ++ chain_type_runners
  end

  @impl Stage
  def all_runners do
    all_extra_runners =
      @extra_runners_by_chain_type
      |> Map.values()
      |> Enum.concat()

    @default_runners ++ all_extra_runners
  end

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
