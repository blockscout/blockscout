defmodule Explorer.Chain.CeloSigners do
  @moduledoc """
  Data type and schema for signer history for accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          address: Hash.Address.t(),
          signer: Hash.Address.t()
        }

  @attrs ~w(
          address signer
      )a

  @required_attrs ~w(
          address signer
      )a

  # Signer change events
  @validator_signer_authorized "0x16e382723fb40543364faf68863212ba253a099607bf6d3a5b47e50a8bf94943"
  @vote_signer_authorized "0xaab5f8a189373aaa290f42ae65ea5d7971b732366ca5bf66556e76263944af28"
  @attestation_signer_authorized "0x9dfbc5a621c3e2d0d83beee687a17dfc796bbce2118793e5e254409bb265ca0b"

  # Events for updating account
  def signer_events, do: [
    @validator_signer_authorized,
    @vote_signer_authorized,
    @attestation_signer_authorized
  ]

  schema "celo_signers" do

    belongs_to(
      :account_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :signer_address,
      Address,
      foreign_key: :signer,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_signers, attrs) do
    celo_signers
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_signer_key, name: :celo_signer_address_signer_index)
  end
end
