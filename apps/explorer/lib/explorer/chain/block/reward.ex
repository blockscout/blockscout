defmodule Explorer.Chain.Block.Reward do
  @moduledoc """
  Represents the static reward given to the miner of a block in a range of block numbers.
  """

  use Ecto.Schema

  alias Explorer.Chain.Block.{Range, Reward}
  alias Explorer.Chain.Wei

  @typedoc """
  The static reward given to the miner of a block.

  * `:block_range` - Range of block numbers
  * `:reward` - Reward given in Wei
  """
  @type t :: %Reward{
          block_range: Range.t(),
          reward: Wei.t()
        }

  @primary_key false
  schema "block_rewards" do
    field(:block_range, Range)
    field(:reward, Wei)
  end
end
