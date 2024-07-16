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
    Runner.Address.TokenBalances,
    Runner.TransactionActions,
    Runner.Withdrawals
  ]

  @optimism_runners [
    Runner.Optimism.FrameSequences,
    Runner.Optimism.FrameSequenceBlobs,
    Runner.Optimism.TxnBatches,
    Runner.Optimism.OutputRoots,
    Runner.Optimism.DisputeGames,
    Runner.Optimism.Deposits,
    Runner.Optimism.Withdrawals,
    Runner.Optimism.WithdrawalEvents
  ]

  @polygon_edge_runners [
    Runner.PolygonEdge.Deposits,
    Runner.PolygonEdge.DepositExecutes,
    Runner.PolygonEdge.Withdrawals,
    Runner.PolygonEdge.WithdrawalExits
  ]

  @polygon_zkevm_runners [
    Runner.PolygonZkevm.LifecycleTransactions,
    Runner.PolygonZkevm.TransactionBatches,
    Runner.PolygonZkevm.BatchTransactions,
    Runner.PolygonZkevm.BridgeL1Tokens,
    Runner.PolygonZkevm.BridgeOperations
  ]

  @zksync_runners [
    Runner.ZkSync.LifecycleTransactions,
    Runner.ZkSync.TransactionBatches,
    Runner.ZkSync.BatchTransactions,
    Runner.ZkSync.BatchBlocks
  ]

  @shibarium_runners [
    Runner.Shibarium.BridgeOperations
  ]

  @ethereum_runners [
    Runner.Beacon.BlobTransactions
  ]

  @arbitrum_runners [
    Runner.Arbitrum.Messages,
    Runner.Arbitrum.LifecycleTransactions,
    Runner.Arbitrum.L1Executions,
    Runner.Arbitrum.L1Batches,
    Runner.Arbitrum.BatchBlocks,
    Runner.Arbitrum.BatchTransactions,
    Runner.Arbitrum.DaMultiPurposeRecords
  ]

  @impl Stage
  def runners do
    case Application.get_env(:explorer, :chain_type) do
      :optimism ->
        @default_runners ++ @optimism_runners

      :polygon_edge ->
        @default_runners ++ @polygon_edge_runners

      :polygon_zkevm ->
        @default_runners ++ @polygon_zkevm_runners

      :shibarium ->
        @default_runners ++ @shibarium_runners

      :ethereum ->
        @default_runners ++ @ethereum_runners

      :zksync ->
        @default_runners ++ @zksync_runners

      :arbitrum ->
        @default_runners ++ @arbitrum_runners

      _ ->
        @default_runners
    end
  end

  @impl Stage
  def all_runners do
    @default_runners ++
      @ethereum_runners ++
      @optimism_runners ++
      @polygon_edge_runners ++ @polygon_zkevm_runners ++ @shibarium_runners ++ @zksync_runners ++ @arbitrum_runners
  end

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
