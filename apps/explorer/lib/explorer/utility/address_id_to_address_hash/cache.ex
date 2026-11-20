# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.AddressIdToAddressHash.Cache do
  @moduledoc """
  Keeps the most recently used `address_hash` ↔ `address_id` mappings of
  `Explorer.Utility.AddressIdToAddressHash` in ETS, so that resolving them does
  not query the database every time.

  A mapping is never changed or deleted once it is created, so a cached one needs
  no invalidation. That holds for committed mappings only: a mapping created
  inside a transaction is gone if the transaction rolls back, and the address
  hash gets another id once it is created again. A rolled back mapping would stay
  in the cache, so only the mappings read or created outside of a transaction are
  cached, see `put/2`.

  Each direction is kept in its own table. A table holds at most `:cache_max_size`
  entries of the `Explorer.Utility.AddressIdToAddressHash` config
  (`ADDRESS_ID_CACHE_MAX_SIZE`); a pair cached in both tables takes about 225
  bytes. Every entry keeps the time of its last access, and once a table outgrows
  the limit, its least recently used entries are evicted until it is 10% below
  the limit.

  The cache is started only when `:cache_max_size` is positive. While it is not
  running, every lookup misses and nothing is cached.
  """

  use GenServer

  alias Explorer.Chain.Hash
  alias Explorer.Utility.AddressIdToAddressHash

  @ids_table :address_hash_to_address_id_cache
  @hashes_table :address_id_to_address_hash_cache

  @byte_count Hash.Address.byte_count()

  # The number of entries the eviction estimates the cutoff access from.
  @sample_size 10_000

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@ids_table, [:set, :named_table, :public, write_concurrency: true])
    :ets.new(@hashes_table, [:set, :named_table, :public, write_concurrency: true])

    {:ok, nil}
  end

  @impl true
  def handle_cast(:evict, state) do
    max_size = max_size()

    evict(@ids_table, max_size)
    evict(@hashes_table, max_size)

    {:noreply, state}
  end

  @doc """
  Tells whether the cache is configured to run, that is, whether its size limit is
  positive.
  """
  @spec enabled?() :: boolean()
  def enabled?, do: max_size() > 0

  @doc """
  Looks up the address ids of the given address hashes.

  Returns the ids found, by address hash, and the values that are not cached, in
  the given order. Values other than `Hash.Address` structs are never cached, so
  they are always among the latter.
  """
  @spec get_ids([Hash.Address.t() | term()]) :: {%{Hash.Address.t() => non_neg_integer()}, [term()]}
  def get_ids(address_hashes) do
    get(address_hashes, fn
      %Hash{bytes: bytes} -> access(@ids_table, bytes)
      _ -> nil
    end)
  end

  @doc """
  Looks up the address hashes of the given address ids.

  Returns the hashes found, by address id, and the values that are not cached, in
  the given order. Values other than integers are never cached, so they are
  always among the latter.
  """
  @spec get_hashes([non_neg_integer() | term()]) :: {%{non_neg_integer() => Hash.Address.t()}, [term()]}
  def get_hashes(address_ids) do
    get(address_ids, fn
      address_id when is_integer(address_id) ->
        with bytes when is_binary(bytes) <- access(@hashes_table, address_id) do
          %Hash{byte_count: @byte_count, bytes: bytes}
        end

      _ ->
        nil
    end)
  end

  @doc """
  Caches the given `{address_id, address_hash}` mappings, which `repo` has just
  returned.

  Nothing is cached if `repo` returned the mappings inside a transaction: they are
  committed only with the transaction, which can still roll back.
  """
  @spec put([{non_neg_integer(), Hash.Address.t()}], Ecto.Repo.t()) :: :ok
  def put([], _repo), do: :ok

  def put(mappings, repo) do
    if running?() and not repo.in_transaction?() do
      insert(mappings)
    end

    :ok
  end

  defp get(keys, access_fun) do
    if running?(), do: split_found(keys, access_fun), else: {%{}, keys}
  rescue
    # The tables go away with the process.
    ArgumentError -> {%{}, keys}
  end

  defp split_found(keys, access_fun) do
    {found, missing} =
      Enum.reduce(keys, {%{}, []}, fn key, {found, missing} ->
        case access_fun.(key) do
          nil -> {found, [key | missing]}
          value -> {Map.put(found, key, value), missing}
        end
      end)

    {found, Enum.reverse(missing)}
  end

  # Returns the cached value of `key` and records the access.
  defp access(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, _last_access}] ->
        :ets.update_element(table, key, {3, next_access()})
        value

      [] ->
        nil
    end
  end

  defp insert(mappings) do
    :ets.insert(
      @ids_table,
      Enum.map(mappings, fn {address_id, %Hash{bytes: bytes}} -> {bytes, address_id, next_access()} end)
    )

    :ets.insert(
      @hashes_table,
      Enum.map(mappings, fn {address_id, %Hash{bytes: bytes}} -> {address_id, bytes, next_access()} end)
    )

    max_size = max_size()

    if :ets.info(@ids_table, :size) > max_size or :ets.info(@hashes_table, :size) > max_size do
      GenServer.cast(__MODULE__, :evict)
    end
  rescue
    # The tables go away with the process.
    ArgumentError -> :ok
  end

  # Strictly increasing, so that no two entries share their last access and the
  # eviction cutoff separates the entries exactly.
  defp next_access, do: :erlang.unique_integer([:monotonic, :positive])

  defp evict(table, max_size) do
    size = :ets.info(table, :size)

    if size > max_size do
      # Going below the limit leaves room for new entries, so that the eviction
      # doesn't run again after every insert.
      count = size - (max_size - div(max_size, 10))

      if delete_least_recently_used(table, size, count) > 0, do: evict(table, max_size)
    end

    :ok
  end

  # Deletes about `count` of the `size` entries of `table`, those accessed least
  # recently, and returns the number of deleted entries.
  #
  # Sorting the whole table by access would take too long and too much memory, so
  # the access below which `count` entries lie is estimated from a sample. The
  # entries are spread over the table by the hash of their key, so its first
  # entries are a random sample with respect to their accesses. A table that fits
  # into the sample is sorted whole, so exactly `count` entries are deleted there.
  defp delete_least_recently_used(table, size, count) when count >= size do
    :ets.delete_all_objects(table)

    size
  end

  defp delete_least_recently_used(table, size, count) do
    case :ets.select(table, [{{:_, :_, :"$1"}, [], [:"$1"]}], @sample_size) do
      {accesses, _continuation} ->
        sample_size = length(accesses)
        index = (count * sample_size) |> div(size) |> max(1) |> min(sample_size - 1)
        cutoff = accesses |> Enum.sort() |> Enum.at(index)

        :ets.select_delete(table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])

      :"$end_of_table" ->
        0
    end
  end

  defp running?, do: :ets.whereis(@ids_table) != :undefined

  defp max_size do
    Application.get_env(:explorer, AddressIdToAddressHash, [])[:cache_max_size] || 0
  end
end
