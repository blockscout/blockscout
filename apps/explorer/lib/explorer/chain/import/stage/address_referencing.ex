defmodule Explorer.Chain.Import.Stage.AddressReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Address.t/0` and that were imported by
  `Explorer.Chain.Import.Stage.Addresses`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Blocks,
      Runner.Address.CoinBalances,
      Runner.Address.CoinBalancesDaily,
      Runner.Tokens,
      Runner.StakingPools,
      Runner.StakingPoolsDelegators
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.concurrent_multis(runners(), runner_to_changes_list, options)
  end
end
