defmodule Explorer.Chain.CeloValidatorGroup do
  @moduledoc """
  Datatype for storing Celo validator groups
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          address: Hash.Address.t(),
          commission: Wei.t(),
          votes: Wei.t()
        }

  @attrs ~w(
        address commission votes
    )a

  @required_attrs ~w(
        address
    )a

  schema "celo_validator_group" do
    field(:commission, Wei)
    field(:votes, Wei)

    belongs_to(
      :validator_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_validator_group, attrs) do
    celo_validator_group
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end
end
