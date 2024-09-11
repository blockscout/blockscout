defmodule Explorer.Chain.Address.BadgeToAddress do
  @moduledoc """
  Defines Address.Badge.t() mapping with Address.t()
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.Address.Badge

  import Ecto.Query, only: [from: 2]

  @typedoc """
  * `address` - the `t:Explorer.Chain.Address.t/0`.
  * `address_hash` - foreign key for `address`.
  * `badge` - the `t:Explorer.Chain.Address.Badge.t/0`.
  * `badge_id` - foreign key for `badge`.
  """
  @primary_key false
  typed_schema "address_badge_mappings" do
    belongs_to(:badge, Badge, foreign_key: :badge_id, type: :integer, null: false)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address, null: false)

    timestamps()
  end

  @required_fields ~w(address_hash badge_id)a
  @allowed_fields @required_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> foreign_key_constraint(:badge_id)
  end

  @doc """
  Creates Address.BadgeToAddress.t() by Address.Badge.t() id and list of Hash.Address.t()
  """
  @spec create(non_neg_integer(), [Hash.Address.t()]) :: {non_neg_integer(), [__MODULE__.t()]}
  def create(badge_id, address_hashes) do
    now = DateTime.utc_now()

    insert_params =
      address_hashes
      |> Enum.map(fn address_hash_string ->
        case Chain.string_to_address_hash(address_hash_string) do
          {:ok, address_hash} -> %{badge_id: badge_id, address_hash: address_hash, inserted_at: now, updated_at: now}
          :error -> nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    Repo.insert_all(__MODULE__, insert_params, on_conflict: :nothing, returning: [:badge_id, :address_hash])
  end

  @doc """
  Deletes Address.BadgeToAddress.t() by Address.Badge.t() id and list of Hash.Address.t()
  """
  @spec delete(non_neg_integer(), [Hash.Address.t()]) :: {non_neg_integer(), [__MODULE__.t()]}
  def delete(badge_id, address_hashes) do
    query =
      from(
        bta in __MODULE__,
        where: bta.badge_id == ^badge_id,
        where: bta.address_hash in ^address_hashes,
        select: bta
      )

    Repo.delete_all(query)
  end

  @doc """
  Gets Address.BadgeToAddress.t() by Address.Badge.t() id
  """
  @spec get(non_neg_integer(), [Chain.necessity_by_association_option() | Chain.api?()]) :: [__MODULE__.t()]
  def get(badge_id, options) do
    query = from(badge_to_address in __MODULE__, where: badge_to_address.badge_id == ^badge_id)

    query
    |> Chain.select_repo(options).all()
  end
end
