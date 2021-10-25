defmodule Explorer.Chain.PendingCelo do
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
          address: Hash.Address.t(),
          timestamp: DateTime.t(),
          amount: Wei.t(),
          index: non_neg_integer()
        }

  @attrs ~w(
        account_address timestamp amount index
    )a

  @required_attrs ~w(
        address
    )a

  @primary_key false
  schema "pending_celo" do
    field(:timestamp, :utc_datetime_usec)
    field(:index, :integer, primary_key: true)
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

  def changeset(%__MODULE__{} = pending_celo, attrs) do
    pending_celo
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:pending_celo_key, name: :pending_celo_account_address_index_index)
  end
end
