defmodule Explorer.Utility.AddressIdToAddressHash do
  @moduledoc """
  Module is responsible for keeping the address_id to address_hash correspondence.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @primary_key false
  typed_schema "address_ids_to_address_hashes" do
    field(:address_id, :integer, primary_key: true)

    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  @doc false
  def changeset(address_id_to_address_hash \\ %__MODULE__{}, params) do
    cast(address_id_to_address_hash, params, [:address_id, :address_hash])
  end

  @doc """
  Finds the mapping for the given address hash or creates it if it does not yet
  exist.

  This function is a convenience wrapper around `find_or_create_multiple/2`
  for a single address hash.

  ## Parameters
  - `address_hash`: The address hash to look up or create a mapping for

  ## Returns
  - An `%Explorer.Utility.AddressIdToAddressHash{}` struct for the given hash
  - `nil` if `address_hash` is `nil`
  """
  @spec find_or_create(Hash.Address.t() | nil) :: __MODULE__.t() | nil
  def find_or_create(address_hash) do
    [address_hash]
    |> find_or_create_multiple(false)
    |> List.first()
  end

  @doc """
  Finds or creates mappings for the given address hashes in bulk.

  The input is normalized by removing `nil` values, deduplicating hashes, and
  casting each hash to `Hash.Address`. Missing mappings are inserted with
  `on_conflict: :nothing`, so existing mappings are preserved.

  ## Parameters
  - `address_hashes`: A list of address hashes to resolve
  - `to_map?`: When `true`, returns a map of `%{address_hash => address_id}`.
    When `false`, returns the list of `%Explorer.Utility.AddressIdToAddressHash{}`
    records

  ## Returns
  - A map of address hashes to address ids when `to_map?` is `true`
  - A list of `%Explorer.Utility.AddressIdToAddressHash{}` structs when
    `to_map?` is `false`
  """
  @spec find_or_create_multiple([Hash.Address.t() | nil], true) :: %{optional(Hash.Address.t()) => integer()}
  @spec find_or_create_multiple([Hash.Address.t() | nil], false) :: [__MODULE__.t()]
  def find_or_create_multiple(address_hashes, to_map? \\ true) do
    filtered_address_hashes =
      address_hashes
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map(fn address_hash ->
        {:ok, casted} = Hash.Address.cast(address_hash)
        casted
      end)

    Repo.insert_all(
      __MODULE__,
      Enum.map(filtered_address_hashes, &%{address_hash: &1}),
      on_conflict: :nothing
    )

    __MODULE__
    |> where([a], a.address_hash in ^filtered_address_hashes)
    |> Repo.all()
    |> then(fn records ->
      if to_map?, do: Map.new(records, &{to_string(&1.address_hash), &1.address_id}), else: records
    end)
  end

  @doc """
  Retrieves the address_id for a given address_hash.

  ## Parameters
  - `hash`: The address hash to look up

  ## Returns
  - The address_id if found, nil otherwise
  """
  @spec hash_to_id(Hash.Address.t()) :: integer() | nil
  def hash_to_id(nil), do: nil

  def hash_to_id(hash) do
    __MODULE__
    |> where([a], a.address_hash == ^hash)
    |> select([a], a.address_id)
    |> Repo.one()
  end

  @doc """
  Retrieves the address hash for a given address_id.

  This function is a convenience wrapper around `ids_to_hashes/1` for a single
  address id.

  ## Parameters
  - `id`: The address id to look up

  ## Returns
  - The address hash if found
  - `nil` if the id is `nil` or no mapping exists
  """
  @spec id_to_hash(integer() | nil) :: Hash.Address.t() | nil
  def id_to_hash(nil), do: nil

  def id_to_hash(id) do
    [id]
    |> ids_to_hashes()
    |> List.first()
  end

  @doc """
  Retrieves all address hashes for the given address ids.

  ## Parameters
  - `ids`: A list of address ids to look up

  ## Returns
  - A list of address hashes for the matching mappings
  """
  @spec ids_to_hashes([integer()]) :: [Hash.Address.t()]
  def ids_to_hashes([]), do: []

  def ids_to_hashes(ids) do
    __MODULE__
    |> where([a], a.address_id in ^ids)
    |> select([a], a.address_hash)
    |> Repo.all()
  end
end
