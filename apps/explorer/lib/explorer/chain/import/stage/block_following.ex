defmodule Explorer.Chain.Import.Stage.BlockFollowing do
  @moduledoc """
  Imports any tables that follows and cannot be imported at the same time as
  those imported by `Explorer.Chain.Import.Stage.Addresses`,
  `Explorer.Chain.Import.Stage.AddressReferencing` and
  `Explorer.Chain.Import.Stage.BlockReferencing`
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Block.SecondDegreeRelations,
      Runner.Block.Rewards,
      Runner.Address.CurrentTokenBalances
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
