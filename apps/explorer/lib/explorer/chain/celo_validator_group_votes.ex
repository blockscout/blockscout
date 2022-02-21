defmodule Explorer.Chain.CeloValidatorGroupVotes do
  @moduledoc """
  Tracks validator group votes one block before an epoch block.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, CeloValidatorGroup, Hash, Wei}

  @required_attrs ~w(block_hash group_hash previous_block_active_votes)a

  @typedoc """
   * `block_hash` - the hash of the epoch block.
   * `group_hash` - the hash of the group.
   * `previous_block_active_votes` - number of activated votes for this group one block before the epoch block.
  """
  @type t :: %__MODULE__{
          block_hash: Hash.Full.t(),
          group_hash: Hash.Full.t(),
          previous_block_active_votes: Wei.t()
        }

  @primary_key false
  schema "celo_validator_group_votes" do
    field(:previous_block_active_votes, Wei)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, primary_key: true, references: :hash, type: Hash.Full)

    belongs_to(:addresses, Explorer.Chain.Address,
      foreign_key: :group_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  def changeset(%__MODULE__{} = celo_validator_group_votes, attrs) do
    celo_validator_group_votes
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> foreign_key_constraint(:group_hash)
    |> unique_constraint([:block_hash, :group_hash], name: :celo_validator_group_votes_block_hash_group_hash_index)
  end

  def default_on_conflict do
    from(
      celo_validator_group_votes in __MODULE__,
      update: [
        set: [
          fetch_epoch_rewards:
            celo_validator_group_votes.previous_block_active_votes or fragment("EXCLUDED.previous_block_active_votes"),
          # Don't update `block_hash` as it is used for the conflict target
          inserted_at: celo_validator_group_votes.inserted_at,
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ],
      where:
        fragment("EXCLUDED.previous_block_active_votes <> ?", celo_validator_group_votes.previous_block_active_votes)
    )
  end
end
