defmodule Explorer.Chain.Celo.Account do
  @moduledoc """
  Represents a Celo account
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @typedoc """
  * `address` - address of the account.
  * `type` - regular, validator or validator group
  * `locked_celo` - total locked celo
  * `nonvoting_locked_celo` - non-voting locked celo
  * `rewards` - rewards in CELO
  """

  @required_attrs ~w(address_hash type)a
  @optional_attrs ~w(name metadata_url nonvoting_locked_celo locked_celo attestations_requested attestations_fulfilled)a
  @allowed_attrs @required_attrs ++ @optional_attrs

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
    field(:attestations_requested, :integer)
    field(:attestations_fulfilled, :integer)

    belongs_to(
      :address,
      Address,
      primary_key: true,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = celo_account, attrs) do
    celo_account
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end
end
