defmodule Explorer.Chain.CeloAttestationStats do
  @moduledoc """
  Datatype for storing Celo voter rewards
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  """

  @type t :: %__MODULE__{
          address_hash: Hash.Address.t(),
          requested: non_neg_integer(),
          fulfilled: non_neg_integer()
        }

  schema "celo_attestation_stats" do
    field(:requested, :integer)
    field(:fulfilled, :integer)

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )
  end
end
