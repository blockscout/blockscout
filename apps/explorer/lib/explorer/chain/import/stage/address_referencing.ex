defmodule Explorer.Chain.Import.Stage.AddressReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Address.t/0` and that were imported by
  `Explorer.Chain.Import.Stage.Addresses`.
  """

  alias Ecto.Multi
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Stage

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Import.Address.CoinBalances,
      Import.Blocks,
      Import.Block.SecondDegreeRelations,
      Import.Transactions,
      Import.Transaction.Forks,
      Import.Logs,
      Import.Tokens,
      Import.TokenTransfers,
      Import.Address.CurrentTokenBalances,
      Import.Address.TokenBalances
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
