defmodule Explorer.Chain.Import.Stage.TokenBalances do
  alias Explorer.Chain.Import.{Runner, Stage}

  @moduledoc """
  Imports token balances.
  """

  @behaviour Stage

  @runner Runner.Address.TokenBalances

  @impl Stage
  def runners, do: [@runner]

  @chunk_size 50

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.chunk_every(runner_to_changes_list, @runner, @chunk_size, options)
  end
end
