defmodule Explorer.Chain.CeloSigners do
  @moduledoc """
  Data type and schema for signer history for accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, CeloAccount, CeloValidator, Hash}

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

    has_one(:celo_account, CeloAccount, foreign_key: :address, references: :address)
    has_one(:celo_validator, CeloValidator, foreign_key: :address, references: :address)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_signers, attrs) do
    celo_signers
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_signer_key, name: :celo_signer_address_signer_index)
  end
end
