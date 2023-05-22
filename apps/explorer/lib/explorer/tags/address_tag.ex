defmodule Explorer.Tags.AddressTag do
  @moduledoc """
  Represents a Tag object.
  """

  use Explorer.Schema

  import Ecto.Changeset

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}

  @typedoc """
  * `:id` - id of Tag
  * `:label` - Tag's label
  * `:label` - Label's display name
  """
  @type t :: %AddressTag{
          label: String.t()
        }

  schema "address_tags" do
    field(:label, :string)
    field(:display_name, :string)
    has_many(:addresses, Address, foreign_key: :hash)
    has_many(:tag_id, AddressToTag, foreign_key: :id)

    timestamps()
  end

  @required_attrs ~w(label display_name)a

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:label, name: :address_tags_label_index)
  end

  def set_tag(name, display_name) do
    tag = get_tag(name)

    if tag do
      tag
      |> AddressTag.changeset(%{display_name: display_name})
      |> Repo.update()
    else
      %AddressTag{}
      |> AddressTag.changeset(%{label: name, display_name: display_name})
      |> Repo.insert()
    end
  end

  def get_tag_id(nil), do: nil

  def get_tag_id(label) do
    query =
      from(
        tag in AddressTag,
        where: tag.label == ^label,
        select: tag.id
      )

    query
    |> Repo.one()
  end

  def get_tag(nil), do: nil

  def get_tag(label) do
    query =
      from(
        tag in AddressTag,
        where: tag.label == ^label
      )

    query
    |> Repo.one()
  end

  def get_all_tags do
    query =
      from(
        tag in AddressTag,
        select: tag
      )

    query
    |> Repo.all()
  end
end
