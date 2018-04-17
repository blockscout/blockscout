defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Credit, Debit}

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
  * `balance` - `credit.value - debit.value`
  * `balance_updated_at` - the last time `balance` was recalculated
  * `credit` - accumulation of all credits to the address `hash`
  * `debit` - accumulation of all debits to the address `hash`
  * `inserted_at` - when this address was inserted
  * `updated_at` when this address was last updated
  """
  @type t :: %__MODULE__{
          balance: Decimal.t(),
          balance_updated_at: DateTime.t(),
          credit: Ecto.Association.NotLoaded.t() | Credit.t() | nil,
          debit: Ecto.Association.NotLoaded.t() | Debit.t() | nil,
          hash: hash(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "addresses" do
    field(:balance, :decimal)
    field(:balance_updated_at, Timex.Ecto.DateTime)
    field(:hash, :string)

    timestamps()

    has_one(:credit, Credit)
    has_one(:debit, Debit)
  end

  @required_attrs ~w(hash)a
  @optional_attrs ~w()a

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> put_balance_updated_at()
  end

  defp put_balance_updated_at(changeset) do
    changeset
    |> put_change(:balance_updated_at, Timex.now())
  end
end
