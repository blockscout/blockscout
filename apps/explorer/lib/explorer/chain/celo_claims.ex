defmodule Explorer.Chain.CeloClaims do
  @moduledoc """
  Data type and schema for user claims
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the user.
  *
  """

  @type t :: %__MODULE__{
               address: Hash.Address.t(),
               type: String.t(),
               element: String.t(),
               verified: Boolean.t()
             }

  @attrs ~w(
    address type domain
      )a

  @required_attrs ~w(
    address type verified
      )a


  schema "celo_claims" do
    belongs_to(
      :account_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    field(:type, :string)
    field(:element, :string)
    field(:verified, :boolean)
    field(:timestamp, :utc_datetime_usec)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_claims, attrs) do
    celo_claims
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end
end
