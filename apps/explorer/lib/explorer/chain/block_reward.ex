defmodule Explorer.Chain.BlockReward do
  @moduledoc """
  TODO
  """

  use Ecto.Schema

  alias Explorer.Chain.{BlockRange, BlockReward, Wei}

  @typedoc """
  The static reward given to the miner of a block.

  * `:block_range` - Range of block numbers
  * `:reward` - Reward given in Wei
  """
  @type t :: %BlockReward{
          block_range: BlockRange.t(),
          reward: Wei.t()
        }

  @primary_key false
  schema "block_rewards" do
    field(:block_range, BlockRange)
    field(:reward, Wei)
  end
end
