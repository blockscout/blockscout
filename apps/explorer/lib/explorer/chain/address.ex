defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Credit, Debit, Hash}

  # Constants

  @optional_attrs ~w()a
  @required_attrs ~w(hash)a

  # Types

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
  * `balance` - `credit.value - debit.value`
  * `balance_updated_at` - the last time `balance` was recalculated
  * `credit` - accumulation of all credits to the address `hash`
  * `debit` - accumulation of all debits to the address `hash`
  * `hash` - the hash of the address's public key
  * `inserted_at` - when this address was inserted
  * `updated_at` when this address was last updated
  """
  @type t :: %__MODULE__{
          balance: Decimal.t(),
          balance_updated_at: DateTime.t(),
          credit: Ecto.Association.NotLoaded.t() | Credit.t() | nil,
          debit: Ecto.Association.NotLoaded.t() | Debit.t() | nil,
          hash: Hash.Truncated.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:hash, Hash.Truncated, autogenerate: false}
  schema "addresses" do
    field(:balance, :decimal)
    field(:balance_updated_at, Timex.Ecto.DateTime)

    timestamps()

    has_one(:credit, Credit)
    has_one(:debit, Debit)
  end

  # Functions

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> put_balance_updated_at()
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  def hash_set_to_changes_list(hash_set) do
    Enum.map(hash_set, &hash_to_changes/1)
  end

  ## Private Functions

  defp hash_to_changes(%Hash{byte_count: 20} = hash) do
    %{hash: hash}
  end

  defp put_balance_updated_at(changeset) do
    changeset
    |> put_change(:balance_updated_at, Timex.now())
  end

  defimpl String.Chars do
    def to_string(%@for{hash: hash}) do
      @protocol.to_string(hash)
    end
  end
end
