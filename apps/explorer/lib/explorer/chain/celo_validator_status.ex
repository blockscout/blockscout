defmodule Explorer.Chain.CeloValidatorStatus do
  @moduledoc """
  Data type and schema for storing current validator status
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          signer_address_hash: Hash.Address.t(),
          last_elected: Explorer.Chain.Block.block_number(),
          last_online: Explorer.Chain.Block.block_number()
        }

  @attrs ~w(
        signer_address last_elected last_online
    )a

  @required_attrs ~w(
        address
    )a

  schema "celo_validator_status" do
    field(:last_elected, :integer)
    field(:last_online, :integer)

    belongs_to(
      :signer_address,
      Address,
      foreign_key: :signer_address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_validator_status_key, name: :celo_validator_status_signer_address_hash_index)
  end
end
