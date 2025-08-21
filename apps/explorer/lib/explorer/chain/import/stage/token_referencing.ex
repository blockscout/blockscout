defmodule Explorer.Chain.Import.Stage.TokenReferencing do
  @moduledoc """
  Imports any data that is related to tokens.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @ctb_runner Runner.Address.CurrentTokenBalances

  @rest_runners [
    Runner.Address.TokenBalances
  ]

  @impl Stage
  def runners, do: [@ctb_runner | @rest_runners]

  @impl Stage
  def all_runners, do: runners()

  @ctb_chunk_size 50

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {ctb_multis, remaining_runner_to_changes_list} =
      Stage.chunk_every(runner_to_changes_list, @ctb_runner, @ctb_chunk_size, options)

    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(@rest_runners, remaining_runner_to_changes_list, options)

    {[final_multi | ctb_multis], final_remaining_runner_to_changes_list}
  end
end
