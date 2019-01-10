defmodule Explorer.Chain.Supply.ProofOfAuthority do
  @moduledoc """
  Defines the supply API for calculating supply for POA.

  POA launched on Dec 15, 2017 with 252,460,800 coins with 20% reserved for
  vesting (50,492,160). After 6 months from launch, 25% of the vested amount,
  or 12,623,040, will be unlocked and included in the circulating supply.
  Every 3 months after that, 12.5% of the vested amount, or 6,311,520, will
  be unlocked until the remaining vested portion is unlocked.


  See https://github.com/poanetwork/wiki/wiki/POA-Token-Supply for more
  information.
  """
  use Explorer.Chain.Supply

  alias Explorer.Chain

  @initial_supply 252_460_800
  @reserved_for_vesting 50_492_160

  @vesting_unlock_dates_and_percentages %{
    ~D[2018-06-15] => 0.25,
    ~D[2018-09-15] => 0.125,
    ~D[2018-12-15] => 0.125,
    ~D[2019-03-15] => 0.125,
    ~D[2019-06-15] => 0.125,
    ~D[2019-09-15] => 0.125,
    ~D[2019-12-15] => 0.125
  }

  def circulating do
    total() - reserved_supply(Date.utc_today())
  end

  def total do
    initial_supply() + Chain.block_height()
  end

  @doc false
  def initial_supply, do: @initial_supply

  @doc false
  @spec reserved_supply(Date.t()) :: non_neg_integer()
  def reserved_supply(%Date{} = date) do
    reserved_as_float =
      Enum.reduce(@vesting_unlock_dates_and_percentages, @reserved_for_vesting, fn {unlock_date, percentage}, acc ->
        if Date.compare(date, unlock_date) in [:eq, :gt] do
          acc - percentage * @reserved_for_vesting
        else
          acc
        end
      end)

    Kernel.trunc(reserved_as_float)
  end
end
