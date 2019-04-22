defmodule Explorer.Chain.Import.Stage.AddressReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Address.t/0` and that were imported by
  `Explorer.Chain.Import.Stage.Addresses`.
  """

  alias Ecto.Multi
  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Address.CoinBalances,
      Runner.Blocks,
      Runner.Block.Rewards,
      Runner.Block.SecondDegreeRelations,
      Runner.Transactions,
      Runner.Transaction.Forks,
      Runner.InternalTransactions,
      Runner.InternalTransactionsIndexedAtBlocks,
      Runner.Logs,
      Runner.Tokens,
      Runner.TokenTransfers,
      Runner.Address.CurrentTokenBalances,
      Runner.Address.TokenBalances,
      Runner.StakingPools
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      runners()
      |> Enum.reduce({Multi.new(), runner_to_changes_list}, fn runner, {multi, remaining_runner_to_changes_list} ->
        {changes_list, new_remaining_runner_to_changes_list} = Map.pop(remaining_runner_to_changes_list, runner)

        new_multi =
          case changes_list do
            nil ->
              multi

            _ ->
              runner.run(multi, changes_list, options)
          end

        {new_multi, new_remaining_runner_to_changes_list}
      end)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
