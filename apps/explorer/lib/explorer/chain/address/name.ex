defmodule Explorer.Chain.Address.Name do
  @moduledoc """
  Represents a name for an Address.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.{Changeset, Repo}
  alias Explorer.Chain.{Address, Hash}

  import Ecto.Query, only: [from: 2]

  @typedoc """
  * `address` - the `t:Explorer.Chain.Address.t/0` with `value` at end of `block_number`.
  * `address_hash` - foreign key for `address`.
  * `name` - name for the address
  * `primary` - flag for if the name is the primary name for the address
  """
  @primary_key false
  typed_schema "address_names" do
    field(:id, :integer, autogenerate: false, primary_key: true, null: false)
    field(:name, :string, null: false)
    field(:primary, :boolean)
    field(:metadata, :map)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address, null: false)

    timestamps()
  end

  @required_fields ~w(address_hash name)a
  @optional_fields ~w(primary metadata)a
  @allowed_fields @required_fields ++ @optional_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> trim_name()
    |> foreign_key_constraint(:address_hash)
  end

  @doc """
  Sets primary false for all primary names for the given address hash
  """
  @spec clear_primary_address_names(Repo.t(), Hash.Address.t()) :: {:ok, []}
  def clear_primary_address_names(repo, address_hash) do
    query =
      from(
        address_name in __MODULE__,
        where: address_name.address_hash == ^address_hash,
        where: address_name.primary == true,
        # Enforce Name ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :address_hash, asc: :name],
        lock: "FOR NO KEY UPDATE"
      )

    repo.update_all(
      from(n in __MODULE__, join: s in subquery(query), on: n.address_hash == s.address_hash and n.name == s.name),
      set: [primary: false]
    )

    {:ok, []}
  end

  @doc """
  Creates primary address name for the given address hash
  """
  @spec create_primary_address_name(Repo.t(), String.t(), Hash.Address.t()) ::
          {:ok, [__MODULE__.t()]} | {:error, [Changeset.t()]}
  def create_primary_address_name(repo, name, address_hash) do
    params = %{
      address_hash: address_hash,
      name: name,
      primary: true
    }

    %__MODULE__{}
    |> changeset(params)
    |> repo.insert(on_conflict: :nothing, conflict_target: [:address_hash, :name])
  end

  defp trim_name(%Changeset{valid?: false} = changeset), do: changeset

  defp trim_name(%Changeset{valid?: true} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end
end
