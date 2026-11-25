# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.AddressIdToAddressHash do
  @moduledoc """
  Module is responsible for keeping the address_id to address_hash correspondence.

  Lookups and `find_or_create_multiple/2` are answered from
  `Explorer.Utility.AddressIdToAddressHash.Cache` first, and only the mappings
  missing there are read from or created in the database.
  """

  use Explorer.Schema

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash.Cache

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
  casting each hash to `Hash.Address`. Cached mappings are returned without
  touching the database. The rest are inserted with `on_conflict: :nothing`, so
  existing mappings are preserved, and then read back and cached.

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
      |> Enum.sort()

    {cached_ids, missing_address_hashes} = Cache.get_ids(filtered_address_hashes)
    records = find_or_create_missing(missing_address_hashes)

    if to_map? do
      cached_ids
      |> Map.new(fn {address_hash, address_id} -> {to_string(address_hash), address_id} end)
      |> Map.merge(Map.new(records, &{to_string(&1.address_hash), &1.address_id}))
    else
      cached_ids
      |> Enum.map(fn {address_hash, address_id} ->
        Ecto.put_meta(%__MODULE__{address_id: address_id, address_hash: address_hash}, state: :loaded)
      end)
      |> Enum.concat(records)
    end
  end

  defp find_or_create_missing([]), do: []

  defp find_or_create_missing(address_hashes) do
    # taken before the database is touched, see `Cache.put/3`
    cache_epoch = Cache.epoch()

    Repo.safe_insert_all(
      __MODULE__,
      Enum.map(address_hashes, &%{address_hash: &1}),
      on_conflict: :nothing
    )

    records =
      __MODULE__
      |> where([a], a.address_hash in ^address_hashes)
      |> Repo.all()

    Cache.put(Enum.map(records, &{&1.address_id, &1.address_hash}), Repo, cache_epoch)

    records
  end

  @doc """
  Retrieves the address_id for a given address_hash.

  ## Parameters
  - `hash`: The address hash to look up

  ## Returns
  - The address_id if found, nil otherwise
  """
  @spec hash_to_id(Hash.Address.t(), [Chain.api?()]) :: integer() | nil
  def hash_to_id(hash, options \\ [])
  def hash_to_id(nil, _options), do: nil

  def hash_to_id(hash, options) do
    [hash]
    |> hashes_to_ids(options)
    |> List.first()
  end

  @doc """
  Retrieves all address ids for the given address hashes.

  Cached mappings are taken from the cache, the rest are read from the database
  and cached.

  ## Parameters
  - `hashes`: A list of address hashes to look up

  ## Returns
  - A list of address ids for the matching mappings
  """
  @spec hashes_to_ids([Hash.Address.t()], [Chain.api?()]) :: [integer()]
  def hashes_to_ids(hashes, options \\ []) do
    {cached_ids, missing_hashes} =
      hashes
      |> Enum.map(&cast_address_hash/1)
      |> Enum.uniq()
      |> Cache.get_ids()

    fetched_ids =
      missing_hashes
      |> fetch_mappings(:address_hash, options)
      |> Enum.map(fn {address_id, _address_hash} -> address_id end)

    Map.values(cached_ids) ++ fetched_ids
  end

  defp cast_address_hash(value) do
    case Hash.Address.cast(value) do
      {:ok, address_hash} -> address_hash
      :error -> value
    end
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
  @spec id_to_hash(integer() | nil, [Chain.api?()]) :: Hash.Address.t() | nil
  def id_to_hash(id, options \\ [])

  def id_to_hash(nil, _options), do: nil

  def id_to_hash(id, options) do
    [id]
    |> ids_to_hashes(options)
    |> List.first()
  end

  @doc """
  Retrieves all address hashes for the given address ids.

  Cached mappings are taken from the cache, the rest are read from the database
  and cached.

  ## Parameters
  - `ids`: A list of address ids to look up

  ## Returns
  - A list of address hashes for the matching mappings
  """
  @spec ids_to_hashes([integer()], [Chain.api?()]) :: [Hash.Address.t()]
  def ids_to_hashes(ids, options \\ [])

  def ids_to_hashes([], _options), do: []

  def ids_to_hashes(ids, options) do
    {cached_hashes, missing_ids} = ids |> Enum.uniq() |> Cache.get_hashes()

    fetched_hashes =
      missing_ids
      |> fetch_mappings(:address_id, options)
      |> Enum.map(fn {_address_id, address_hash} -> address_hash end)

    Map.values(cached_hashes) ++ fetched_hashes
  end

  # Reads the `{address_id, address_hash}` mappings whose `field` is one of
  # `values`, and caches them.
  defp fetch_mappings([], _field, _options), do: []

  defp fetch_mappings(values, field, options) do
    repo = Chain.select_repo(options)
    # taken before the database is touched, see `Cache.put/3`
    cache_epoch = Cache.epoch()

    mappings =
      __MODULE__
      |> where([a], field(a, ^field) in ^values)
      |> select([a], {a.address_id, a.address_hash})
      |> repo.all()

    Cache.put(mappings, repo, cache_epoch)

    mappings
  end

  @doc """
  Retrieves the address mappings for the given address ids.

  Unlike `ids_to_hashes/2`, the result keeps the id of each hash.

  ## Parameters
  - `ids`: A list of address ids to look up
  - `options`: `api?: true` reads the mappings from the replica

  ## Returns
  - A list of `%Explorer.Utility.AddressIdToAddressHash{}` structs for the
    matching ids
  """
  @spec fetch_by_ids([integer()], [Chain.api?()]) :: [__MODULE__.t()]
  def fetch_by_ids(ids, options \\ [])

  def fetch_by_ids([], _options), do: []

  def fetch_by_ids(ids, options) do
    __MODULE__
    |> where([a], a.address_id in ^ids)
    |> Chain.select_repo(options).all()
  end
end
