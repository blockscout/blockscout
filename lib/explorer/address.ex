defmodule Explorer.Address do
  @moduledoc """
    A stored representation of a web3 address.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Explorer.Address
  alias Explorer.Credit
  alias Explorer.Debit
  alias Explorer.Repo.NewRelic, as: Repo

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "addresses" do
    has_one :credit, Credit
    has_one :debit, Debit
    field :hash, :string
    timestamps()
  end

  @required_attrs ~w(hash)a
  @optional_attrs ~w()a

  def find_or_create_by_hash(hash) do
    query = from a in Address,
      where: fragment("lower(?)", a.hash) == ^String.downcase(hash),
      limit: 1
    case query |> Repo.one() do
      nil -> Repo.insert!(Address.changeset(%Address{}, %{hash: hash}))
      address -> address
    end
  end

  def changeset(%Address{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
