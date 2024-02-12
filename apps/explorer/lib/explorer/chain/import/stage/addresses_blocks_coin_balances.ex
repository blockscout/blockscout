defmodule Explorer.Chain.Import.Stage.AddressesBlocksCoinBalances do
  @moduledoc """
  Import addresses, blocks and balances.
  No tables have foreign key to addresses anymore, so it's possible to import addresses along with them.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @addresses_runner Runner.Addresses

  @rest_runners [
    Runner.Address.CoinBalances,
    Runner.Blocks,
    Runner.Address.CoinBalancesDaily
  ]

  @impl Stage
  def runners, do: [@addresses_runner | @rest_runners]

  @impl Stage
  def all_runners, do: runners()

  @addresses_chunk_size 50

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {addresses_multis, remaining_runner_to_changes_list} =
      Stage.chunk_every(runner_to_changes_list, Runner.Addresses, @addresses_chunk_size, options)

    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(@rest_runners, remaining_runner_to_changes_list, options)

    {[final_multi | addresses_multis], final_remaining_runner_to_changes_list}
  end
end
