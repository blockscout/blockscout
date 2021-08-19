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
