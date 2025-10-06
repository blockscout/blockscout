defmodule Explorer.Chain.Import.Stage.ChainTypeSpecific do
  @moduledoc """
  Imports any chain type specific tables.
  """

  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners_by_chain_type %{
    optimism: [
      Runner.Optimism.FrameSequences,
      Runner.Optimism.FrameSequenceBlobs,
      Runner.Optimism.TransactionBatches,
      Runner.Optimism.OutputRoots,
      Runner.Optimism.DisputeGames,
      Runner.Optimism.Deposits,
      Runner.Optimism.Withdrawals,
      Runner.Optimism.WithdrawalEvents,
      Runner.Optimism.EIP1559ConfigUpdates,
      Runner.Optimism.InteropMessages
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
      Runner.Arbitrum.DaMultiPurposeRecords,
      Runner.Arbitrum.BatchToDaBlobs
    ],
    scroll: [
      Runner.Scroll.BatchBundles,
      Runner.Scroll.Batches,
      Runner.Scroll.BridgeOperations,
      Runner.Scroll.L1FeeParams
    ],
    zilliqa: [
      Runner.Zilliqa.AggregateQuorumCertificates,
      Runner.Zilliqa.NestedQuorumCertificates,
      Runner.Zilliqa.QuorumCertificates,
      Runner.Zilliqa.Zrc2.TokenAdapters,
      Runner.Zilliqa.Zrc2.TokenTransfers
    ],
    stability: [
      Runner.Stability.Validators
    ]
  }

  @runners_by_chain_identity %{
    {:optimism, :celo} => [
      Runner.Celo.PendingAccountOperations,
      Runner.Celo.Accounts,
      Runner.Celo.ValidatorGroupVotes,
      Runner.Celo.Epochs,
      Runner.Celo.ElectionRewards,
      Runner.Celo.EpochRewards,
      Runner.Celo.AggregatedElectionRewards
    ]
  }

  @impl Stage
  def runners do
    chain_type_runners = Map.get(@runners_by_chain_type, chain_type(), [])
    chain_identity_runners = Map.get(@runners_by_chain_identity, chain_identity(), [])
    chain_type_runners ++ chain_identity_runners
  end

  @impl Stage
  def all_runners do
    chain_type_runners =
      @runners_by_chain_type
      |> Map.values()
      |> Enum.concat()

    chain_identity_runners =
      @runners_by_chain_identity
      |> Map.values()
      |> Enum.concat()

    chain_type_runners ++ chain_identity_runners
  end

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
