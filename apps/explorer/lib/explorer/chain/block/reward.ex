defmodule Explorer.Chain.Block.Reward do
  @moduledoc """
  Represents the total reward given to an address in a block.
  """

  use Explorer.Schema

  alias Explorer.Chain.Block.Reward.AddressType
  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @required_attrs ~w(address_hash address_type block_hash reward)a

  @typedoc """
  The validation reward given related to a block.

  * `:address_hash` - Hash of address who received the reward
  * `:address_type` - Type of the address_hash, either emission_funds, uncle or validator
  * `:block_hash` - Hash of the validated block
  * `:reward` - Total block reward
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          address_hash: Hash.Address.t(),
          address_type: AddressType.t(),
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          block_hash: Hash.Full.t(),
          reward: Wei.t()
        }

  @primary_key false
  schema "block_rewards" do
    field(:address_type, AddressType)
    field(:reward, Wei)

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :block,
      Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = reward, attrs) do
    reward
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
