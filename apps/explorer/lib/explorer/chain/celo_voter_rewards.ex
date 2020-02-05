defmodule Explorer.Chain.CeloVoterRewards do
  @moduledoc """
  Datatype for storing Celo voter rewards
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @typedoc """
  * `block_hash` - block where this reward was paid.
  * `log_index` - Log index for the associated event
  """

  @type t :: %__MODULE__{
    block_hash: Hash.Full.t(),
    log_index: non_neg_integer(),
    block_number: non_neg_integer(),
    address_hash: Hash.Address.t(),
    active_votes: Wei.t(),
    reward: Wei.t()
  }

  @attrs ~w( block_hash log_index address_hash active_votes reward block_number )a

  @required_attrs ~w( block_hash log_index )a

  schema "celo_voter_rewards" do
    field(:reward, Wei)
    field(:active_votes, Wei)
    field(:log_index, :integer)
    field(:block_number, :integer)

    belongs_to(
      :group_address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )
    
    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_voter_rewards_key, name: :celo_voter_rewards_block_hash_log_index_index)
  end
end
