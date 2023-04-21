defmodule Explorer.Chain.Import.Stage.Addresses do
  @moduledoc """
  Imports addresses before anything else that references them because an unused address is still valid and recoverable
  if the other stage(s) don't commit.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runner Runner.Addresses

  @impl Stage
  def runners, do: [@runner]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
