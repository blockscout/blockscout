defmodule Explorer.Chain.Import.Stage.TokenInstances do
  @moduledoc """
  Import token instances.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners [
    Runner.TokenInstances
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
