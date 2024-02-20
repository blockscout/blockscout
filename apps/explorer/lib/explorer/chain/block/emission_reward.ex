defmodule Explorer.Chain.Block.EmissionReward do
  @moduledoc """
  Represents the static reward given to the miner of a block in a range of block numbers.
  """

  use Explorer.Schema

  alias Explorer.Chain.Block.Range
  alias Explorer.Chain.Wei

  @typedoc """
  The static reward given to the miner of a block.

  * `:block_range` - Range of block numbers
  * `:reward` - Reward given in Wei
  """
  @primary_key false
  typed_schema "emission_rewards" do
    field(:block_range, Range, null: false)
    field(:reward, Wei, null: false)
  end

  def changeset(%__MODULE__{} = emission_reward, attrs) do
    emission_reward
    |> cast(attrs, [:block_range, :reward])
    |> validate_required([:block_range, :reward])
  end
end
