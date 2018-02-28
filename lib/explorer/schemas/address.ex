defmodule Explorer.Address do
  @moduledoc """
    A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Explorer.Address
  alias Explorer.Credit
  alias Explorer.Debit

  schema "addresses" do
    has_one(:credit, Credit)
    has_one(:debit, Debit)
    field(:hash, :string)
    field(:balance, :decimal)
    field(:balance_updated_at, Timex.Ecto.DateTime)
    timestamps()
  end

  @required_attrs ~w(hash)a
  @optional_attrs ~w()a

  def changeset(%Address{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end

  def balance_changeset(%Address{} = address, attrs) do
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
