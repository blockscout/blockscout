defmodule Explorer.Chain.Import.Stage.BlockTransactionReferencing do
  @moduledoc """
  Imports any data that is related to blocks and transactions.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners [
    Runner.TokenTransfers,
    Runner.Transaction.Forks,
    Runner.Block.Rewards,
    Runner.Block.SecondDegreeRelations,
    Runner.TransactionActions,
    Runner.Withdrawals,
    Runner.SignedAuthorizations
  ]

  @impl Stage
  def runners, do: @runners

  @impl Stage
  def all_runners, do: runners()

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
