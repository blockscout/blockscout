defmodule Explorer.Chain.CeloAccumulatedRewards do
  @moduledoc """
  Datatype for storing Celo voter rewards
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @typedoc """
  """

  @type t :: %__MODULE__{
          address_hash: Hash.Address.t(),
          active: Wei.t(),
          reward: Wei.t()
        }

  schema "celo_accumulated_rewards" do
    field(:reward, Wei)
    field(:active, Wei)

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )
  end
end
