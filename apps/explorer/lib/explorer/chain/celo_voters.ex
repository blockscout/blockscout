defmodule Explorer.Chain.CeloVoters do
  @moduledoc """
  Data type and schema for signer history for accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, CeloValidatorGroup, Hash, Wei}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          group_address_hash: Hash.Address.t(),
          voter_address_hash: Hash.Address.t(),
          active: Wei.t(),
          units: Wei.t(),
          total: Wei.t(),
          pending: Wei.t()
        }

  @attrs ~w(
    group_address_hash voter_address_hash active pending total units
      )a

  @required_attrs ~w(
    group_address_hash voter_address_hash
      )a

  # Voter change events
  @validator_group_active_vote_revoked "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8"
  @validator_group_pending_vote_revoked "0x148075455e24d5cf538793db3e917a157cbadac69dd6a304186daf11b23f76fe"
  @validator_group_vote_activated "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
  @validator_group_vote_cast "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152"

  @voter_rewards "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"

  # Events for updating voter
  def voter_events,
    do: [
      @validator_group_active_vote_revoked,
      @validator_group_pending_vote_revoked,
      @validator_group_vote_activated,
      @validator_group_vote_cast
    ]

  def distributed_events,
    do: [
      @voter_rewards
    ]

  schema "celo_voters" do
    belongs_to(
      :group_address,
      Address,
      foreign_key: :group_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :voter_address,
      Address,
      foreign_key: :voter_address_hash,
      references: :hash,
      type: Hash.Address
    )

    has_one(
      :group,
      CeloValidatorGroup,
      foreign_key: :address,
      references: :group_address_hash
    )

    field(:units, Wei)
    field(:pending, Wei)
    field(:active, Wei)
    field(:total, Wei)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_voters, attrs) do
    celo_voters
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_voter_key, name: :celo_voters_group_address_hash_voter_address_hash_index)
  end
end
