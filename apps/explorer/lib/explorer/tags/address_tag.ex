defmodule Explorer.Tags.AddressTag do
  @moduledoc """
  Represents an address Tag object.
  """

  use Explorer.Schema

  import Ecto.Changeset

  import Ecto.Query,
    only: [
      from: 2,
      select: 3
    ]

  alias Explorer.Repo
  alias Explorer.Tags.AddressToTag

  @typedoc """
  * `:id` - id of Tag
  * `:label` - Tag's label
  * `:display_name` - Label's display name
  """
  typed_schema "address_tags" do
    field(:label, :string, primary_key: true, null: false)
    field(:display_name, :string, null: false)
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

  @spec set(String.t() | nil, String.t() | nil) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()} | :invalid
  def set(name, display_name)

  def set(nil, _), do: :invalid

  def set(_, nil), do: :invalid

  def set(name, display_name) do
    tag = get_by_label(name)

    if tag do
      tag
      |> __MODULE__.changeset(%{display_name: display_name})
      |> Repo.update()
    else
      %__MODULE__{}
      |> __MODULE__.changeset(%{label: name, display_name: display_name})
      |> Repo.insert()
    end
  end

  @doc """
   Fetches AddressTag.t() by label name from the DB
  """
  @spec get_id_by_label(String.t()) :: non_neg_integer()
  def get_id_by_label(nil), do: nil

  def get_id_by_label(label) do
    label
    |> get_by_label_query()
    |> select([tag], tag.id)
    |> Repo.one()
  end

  @doc """
   Fetches all AddressTag.t() from the DB
  """
  @spec get_all() :: __MODULE__.t()
  def get_all do
    __MODULE__
    |> Repo.all()
  end

  defp get_by_label(nil), do: nil

  defp get_by_label(label) do
    label
    |> get_by_label_query()
    |> Repo.one()
  end

  defp get_by_label_query(label) do
    from(
      tag in __MODULE__,
      where: tag.label == ^label
    )
  end
end
