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
      Runner.Tokens
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.split_multis(runners(), runner_to_changes_list, options)
  end
end
