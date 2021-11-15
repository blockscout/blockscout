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
      Runner.Transaction.Forks,
      Runner.Logs,
      Runner.TokenTransfers
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.concurrent_multis(runners(), runner_to_changes_list, options)
  end
end
