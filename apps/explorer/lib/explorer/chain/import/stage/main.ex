defmodule Explorer.Chain.Import.Stage.Main do
  @moduledoc """
  Imports main data (address_coin_balances, address_coin_balances_daily, tokens, transactions).
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners [
    Runner.Tokens,
    Runner.Address.CoinBalances,
    Runner.Address.CoinBalancesDaily,
    Runner.Transactions
  ]

  @impl Stage
  def runners, do: @runners

  @impl Stage
  def all_runners, do: runners()

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(@runners, runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
