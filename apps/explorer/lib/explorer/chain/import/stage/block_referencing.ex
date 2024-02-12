defmodule Explorer.Chain.Import.Stage.BlockReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.AddressesBlocksCoinBalances`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage
  @default_runners [
    Runner.Transactions,
    Runner.Transaction.Forks,
    Runner.Logs,
    Runner.Tokens,
    Runner.TokenTransfers,
    Runner.Address.TokenBalances,
    Runner.TransactionActions,
    Runner.Withdrawals
  ]

  @polygon_edge_runners [
    Runner.PolygonEdge.Deposits,
    Runner.PolygonEdge.DepositExecutes,
    Runner.PolygonEdge.Withdrawals,
    Runner.PolygonEdge.WithdrawalExits
  ]

  @polygon_zkevm_runners [
    Runner.Zkevm.LifecycleTransactions,
    Runner.Zkevm.TransactionBatches,
    Runner.Zkevm.BatchTransactions
  ]

  @shibarium_runners [
    Runner.Shibarium.BridgeOperations
  ]

  @impl Stage
  def runners do
    case System.get_env("CHAIN_TYPE") do
      "polygon_edge" ->
        @default_runners ++ @polygon_edge_runners

      "polygon_zkevm" ->
        @default_runners ++ @polygon_zkevm_runners

      "shibarium" ->
        @default_runners ++ @shibarium_runners

      _ ->
        @default_runners
    end
  end

  @impl Stage
  def all_runners do
    @default_runners ++ @polygon_edge_runners ++ @polygon_zkevm_runners ++ @shibarium_runners
  end

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
