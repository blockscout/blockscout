defmodule Explorer.Address do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Address
  alias Explorer.Repo.NewRelic, as: Repo

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "addresses" do
    field :hash, :string
    timestamps()
  end

  @required_attrs ~w(hash)a
  @optional_attrs ~w()a

  def find_or_create_by_hash(hash) do
    address_attrs = %{hash: hash}
    address_changeset = Address.changeset(%Address{}, %{hash: hash})
    Repo.get_by(Address, address_attrs) || Repo.insert!(address_changeset)
  end

  def changeset(%Address{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
