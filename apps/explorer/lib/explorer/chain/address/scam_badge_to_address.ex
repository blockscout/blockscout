defmodule Explorer.Chain.Address.ScamBadgeToAddress do
  @moduledoc """
  Defines Address.ScamBadgeToAddress.t() mapping with Address.t()
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  import Ecto.Query, only: [from: 2]

  @typedoc """
  * `address` - the `t:Explorer.Chain.Address.t/0`.
  * `address_hash` - foreign key for `address`.
  """
  @primary_key false
  typed_schema "scam_address_badge_mappings" do
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address, null: false)

    timestamps()
  end

  @required_fields ~w(address_hash)a
  @allowed_fields @required_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
  end

  @doc """
  Adds Address.ScamBadgeToAddress.t() by the list of Hash.Address.t()
  """
  @spec add([Hash.Address.t()]) :: {non_neg_integer(), [__MODULE__.t()]}
  def add(address_hashes) do
    now = DateTime.utc_now()

    insert_params =
      address_hashes
      |> Enum.map(fn address_hash_string ->
        case Chain.string_to_address_hash(address_hash_string) do
          {:ok, address_hash} -> %{address_hash: address_hash, inserted_at: now, updated_at: now}
          :error -> nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    Repo.insert_all(__MODULE__, insert_params, on_conflict: :nothing, returning: [:address_hash])
  end

  @doc """
  Deletes Address.ScamBadgeToAddress.t() by the list of Hash.Address.t()
  """
  @spec delete([Hash.Address.t()]) :: {non_neg_integer(), [__MODULE__.t()]}
  def delete(address_hashes) do
    query =
      from(
        bta in __MODULE__,
        where: bta.address_hash in ^address_hashes,
        select: bta
      )

    Repo.delete_all(query)
  end

  @doc """
  Gets the list of Address.ScamBadgeToAddress.t()
  """
  @spec get([Chain.necessity_by_association_option() | Chain.api?()]) :: [__MODULE__.t()]
  def get(options) do
    __MODULE__
    |> Chain.select_repo(options).all()
  end
end
