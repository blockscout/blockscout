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
  """
  @type t :: %AddressTag{
          label: String.t()
        }

  schema "address_tags" do
    field(:label, :string)
    has_many(:addresses, Address, foreign_key: :hash)
    has_many(:tag_id, AddressToTag, foreign_key: :id)

    timestamps()
  end

  @required_attrs ~w(label)a

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:label, name: :address_tags_label_index)
  end

  def set_tag(label) do
    tag_id = get_tag_id(label)

    unless tag_id do
      %AddressTag{}
      |> AddressTag.changeset(%{label: label})
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

  def get_all_tags do
    query =
      from(
        tag in AddressTag,
        select: tag.label
      )

    query
    |> Repo.all()
  end
end
