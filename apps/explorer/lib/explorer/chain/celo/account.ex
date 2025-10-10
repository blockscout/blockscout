defmodule Explorer.Chain.Celo.Account do
  @moduledoc """
  Represents a Celo blockchain account with associated metadata, and locked gold
  amounts.

  Celo accounts can be regular accounts, validators, or validator groups, each
  with different roles in the network governance and consensus mechanisms.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @required_attrs ~w(address_hash)a
  @optional_attrs [
    :type,
    :name,
    :metadata_url,
    :nonvoting_locked_celo,
    :locked_celo,
    :vote_signer_address_hash,
    :validator_signer_address_hash,
    :attestation_signer_address_hash
  ]

  @allowed_attrs @required_attrs ++ @optional_attrs

  @typedoc """
  * `address_hash` - the hash of the account address
  * `type` - account type: regular, validator, or validator group
  * `name` - human-readable name of the account
  * `metadata_url` - URL to additional account metadata
  * `locked_celo` - total amount of CELO locked by this account
  * `nonvoting_locked_celo` - amount of locked CELO that is not used for voting
  * `vote_signer_address_hash` – Address authorized to vote in governance and
    validator elections on behalf of this account.
  * `validator_signer_address_hash` – Address authorized to manage a validator
    or validator group and sign consensus messages for this account.
  * `attestation_signer_address_hash` – Address whose key this account uses to
    sign attestations on the Attestations contract.
  """
  @primary_key false
  typed_schema "celo_accounts" do
    field(:type, Ecto.Enum,
      values: [:regular, :validator, :group],
      default: :regular
    )

    field(:name, :string)
    field(:metadata_url, :string)
    field(:nonvoting_locked_celo, Wei)
    field(:locked_celo, Wei)

    belongs_to(
      :address,
      Address,
      primary_key: true,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(
      :vote_signer_address,
      Address,
      foreign_key: :vote_signer_address_hash,
      references: :hash,
      type: Hash.Address,
      null: true
    )

    belongs_to(
      :validator_signer_address,
      Address,
      foreign_key: :validator_signer_address_hash,
      references: :hash,
      type: Hash.Address,
      null: true
    )

    belongs_to(
      :attestation_signer_address,
      Address,
      foreign_key: :attestation_signer_address_hash,
      references: :hash,
      type: Hash.Address,
      null: true
    )

    timestamps()
  end

  @doc """
  Creates a changeset for a Celo account with the given attributes.

  ## Parameters
  - `celo_account`: The Celo account struct to update
  - `attrs`: A map of attributes to cast and validate

  ## Returns
  - An Ecto changeset with validation results
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = celo_account, attrs) do
    celo_account
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end
end
