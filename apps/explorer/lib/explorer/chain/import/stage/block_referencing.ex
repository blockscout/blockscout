defmodule Explorer.Chain.Import.Stage.BlockReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.Addresses` and
  `Explorer.Chain.Import.Stage.AddressReferencing`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Transactions,
      Runner.Transaction.Forks,
      Runner.Logs,
      Runner.Tokens,
      Runner.TokenTransfers,
      Runner.Address.TokenBalances,
      Runner.TransactionActions,
      Runner.OptimismFrameSequences,
      Runner.OptimismTxnBatches,
      Runner.OptimismOutputRoots,
      Runner.OptimismWithdrawals,
      Runner.OptimismWithdrawalEvents
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
