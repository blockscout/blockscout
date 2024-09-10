defmodule Explorer.Chain.Address.Badge do
  @moduledoc """
  Defines Address.t() badges
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address

  import Ecto.Query, only: [from: 2]

  @typedoc """
  * `id` - id of the badge.
  * `category` - category of the badge.
  * `content` - content of the badge.
  """
  @primary_key false
  typed_schema "address_badges" do
    field(:id, :integer, primary_key: true, null: false)

    field(:category, Ecto.Enum,
      values: [
        :scam
      ],
      null: false
    )

    field(:content, :string, null: false)

    has_many(:address_to_badges, Address.BadgeToAddress, foreign_key: :badge_id, references: :id)

    timestamps()
  end

  @required_fields ~w(category content)a
  @allowed_fields @required_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:category, :content],
      message: "Address badge has been created before"
    )
  end

  @spec get(non_neg_integer(), [Chain.necessity_by_association_option() | Chain.api?()]) :: t() | nil
  def get(badge_id, options) do
    query = from(badge in __MODULE__, where: badge.id == ^badge_id)

    query
    |> Chain.select_repo(options).one()
  end

  def create(category, content) do
    %__MODULE__{}
    |> __MODULE__.changeset(%{category: category, content: content})
    |> Repo.insert(returning: [:id, :category, :content])
  end

  def update(badge, category, content) do
    badge
    |> __MODULE__.changeset(%{category: category, content: content})
    |> Repo.update()
  end

  def delete(badge) do
    badge
    |> Changeset.change()
    |> Repo.delete()
  end
end
