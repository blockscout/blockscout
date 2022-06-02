defmodule Explorer.Chain.Import.Stage.BlockTransactionTokenReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0, t:Explorer.Chain.Transaction.t/0, t:Explorer.Chain.Token.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.Addresses`,
  `Explorer.Chain.Import.Stage.AddressReferencing` and
  `Explorer.Chain.Import.Stage.BlockReferencing`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Transaction.Forks,
      Runner.Logs,
      Runner.TokenTransfers,
      Runner.Address.TokenBalances
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.split_multis(runners(), runner_to_changes_list, options)
  end
end
