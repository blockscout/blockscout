defmodule Explorer.Chain.CeloUnlocked do
  @moduledoc """
  Table for storing unlocked CELO that has not been withdrawn yet.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @typedoc """
  * `address` - address of the validator.
  *
  """

  @type t :: %__MODULE__{
          account_address: Hash.Address.t(),
          available: DateTime.t(),
          amount: Wei.t()
        }

  @attrs ~w(
        available amount
    )a

  @required_attrs ~w(
        account_address
    )a

  @primary_key false
  schema "celo_unlocked" do
    field(:available, :utc_datetime_usec)
    field(:amount, Wei)

    belongs_to(
      :address,
      Address,
      foreign_key: :account_address,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_unlocked, %{address: a} = attrs) do
    attrs = attrs |> Map.delete(:address) |> Map.put(:account_address, a)
    changeset(celo_unlocked, attrs)
  end

  def changeset(%__MODULE__{} = celo_unlocked, attrs) do
    celo_unlocked
    |> cast(attrs, @attrs ++ @required_attrs)
    |> validate_required(@required_attrs)
  end
end
