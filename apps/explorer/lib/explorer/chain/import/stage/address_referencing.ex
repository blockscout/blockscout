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
      Runner.Address.CoinBalances,
      Runner.Address.Names,
      Runner.Blocks,
      Runner.CeloAccounts,
      Runner.CeloAccountEpochs,
      Runner.CeloElectionRewards,
      Runner.CeloEpochRewards,
      Runner.CeloParams,
      Runner.CeloSigners,
      Runner.CeloValidators,
      Runner.CeloValidatorGroups,
      Runner.CeloValidatorHistory,
      Runner.CeloValidatorStatus,
      Runner.CeloVoters,
      Runner.CeloUnlocked,
      Runner.CeloWallets,
      Runner.ExchangeRate,
      Runner.StakingPools,
      Runner.StakingPoolsDelegators,
      Runner.Address.CoinBalancesDaily
    ]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
