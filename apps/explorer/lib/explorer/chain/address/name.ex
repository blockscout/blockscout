defmodule Explorer.Chain.Address.Name do
  @moduledoc """
  Represents a name for an Address.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - the `t:Explorer.Chain.Address.t/0` with `value` at end of `block_number`.
  * `address_hash` - foreign key for `address`.
  * `name` - name for the address
  * `primary` - flag for if the name is the primary name for the address
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          name: String.t(),
          primary: boolean(),
          metadata: map()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "address_names" do
    field(:name, :string)
    field(:primary, :boolean)
    field(:metadata, :map)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)

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

  defp trim_name(%Changeset{valid?: false} = changeset), do: changeset

  defp trim_name(%Changeset{valid?: true} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end
end
