defmodule Explorer.Chain.Import.Stage.TokenReferencing do
  @moduledoc """
  Imports any data that is related to tokens.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners [
    Runner.Address.TokenBalances,
    Runner.Address.CurrentTokenBalances
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
