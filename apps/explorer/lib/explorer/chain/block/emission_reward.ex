defmodule Explorer.Chain.Block.EmissionReward do
  @moduledoc """
  Represents the static reward given to the miner of a block in a range of block numbers.
  """

  use Explorer.Schema

  alias Explorer.Chain.Block.{EmissionReward, Range}
  alias Explorer.Chain.Wei

  @typedoc """
  The static reward given to the miner of a block.

  * `:block_range` - Range of block numbers
  * `:reward` - Reward given in Wei
  """
  @type t :: %EmissionReward{
          block_range: Range.t(),
          reward: Wei.t()
        }

  @primary_key false
  schema "emission_rewards" do
    field(:block_range, Range)
    field(:reward, Wei)
  end

  def changeset(%__MODULE__{} = emission_reward, attrs) do
    emission_reward
    |> cast(attrs, [:block_range, :reward])
    |> validate_required([:block_range, :reward])
  end
end
