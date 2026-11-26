# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.AddressIdToAddressHashTest do
  # The cache is a named process with named tables, shared by all tests.
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Hash
  alias Explorer.Repo.Replica1
  alias Explorer.Utility.AddressIdToAddressHash
  alias Explorer.Utility.AddressIdToAddressHash.Cache

  describe "without the cache" do
    test "lookups read the database" do
      %{address_id: address_id, address_hash: address_hash} = insert(:address_id_to_address_hash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == address_id
      assert AddressIdToAddressHash.hashes_to_ids([to_string(address_hash)]) == [address_id]
      assert AddressIdToAddressHash.id_to_hash(address_id) == address_hash

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == nil
      assert AddressIdToAddressHash.id_to_hash(address_id) == nil
    end

    test "find_or_create_multiple/2 creates the missing mappings" do
      # not the factory: its explicit ids can take the ones the sequence gives next
      existing = AddressIdToAddressHash.find_or_create(address_hash())
      new_hash = address_hash()

      mappings = AddressIdToAddressHash.find_or_create_multiple([existing.address_hash, new_hash, nil])

      assert %{address_id: new_id} = Repo.get_by(AddressIdToAddressHash, address_hash: new_hash)

      assert mappings == %{
               to_string(existing.address_hash) => existing.address_id,
               to_string(new_hash) => new_id
             }
    end
  end

  describe "with the cache" do
    setup do
      start_cache(1_000)
    end

    test "hash_to_id/2 and id_to_hash/2 answer from the cache once the mapping is read" do
      %{address_id: address_id, address_hash: address_hash} = insert(:address_id_to_address_hash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == address_id

      # only a cached answer can still see the mapping that is gone from the database
      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.hash_to_id(address_hash, api?: true) == address_id
      assert AddressIdToAddressHash.id_to_hash(address_id) == address_hash
    end

    test "hashes_to_ids/2 reads only the missing mappings from the database, and caches them" do
      cached = insert(:address_id_to_address_hash)
      missing = insert(:address_id_to_address_hash)

      assert AddressIdToAddressHash.hashes_to_ids([cached.address_hash]) == [cached.address_id]

      Repo.delete_all(from(a in AddressIdToAddressHash, where: a.address_id == ^cached.address_id))

      # a hash given as a string is the same hash
      address_ids =
        AddressIdToAddressHash.hashes_to_ids([
          cached.address_hash,
          to_string(cached.address_hash),
          missing.address_hash
        ])

      assert Enum.sort(address_ids) == Enum.sort([cached.address_id, missing.address_id])

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.id_to_hash(missing.address_id) == missing.address_hash
    end

    test "ids_to_hashes/2 reads only the missing mappings from the database, and caches them" do
      cached = insert(:address_id_to_address_hash)
      missing = insert(:address_id_to_address_hash)

      assert AddressIdToAddressHash.ids_to_hashes([cached.address_id]) == [cached.address_hash]

      Repo.delete_all(from(a in AddressIdToAddressHash, where: a.address_id == ^cached.address_id))

      address_hashes =
        AddressIdToAddressHash.ids_to_hashes([cached.address_id, cached.address_id, missing.address_id, nil])

      assert Enum.sort(address_hashes) == Enum.sort([cached.address_hash, missing.address_hash])

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.hash_to_id(missing.address_hash) == missing.address_id
    end

    test "find_or_create_multiple/2 caches the mappings it creates and doesn't create the cached ones again" do
      address_hash = address_hash()

      mappings = AddressIdToAddressHash.find_or_create_multiple([address_hash])
      assert %{address_id: address_id} = Repo.get_by(AddressIdToAddressHash, address_hash: address_hash)
      assert mappings == %{to_string(address_hash) => address_id}

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.find_or_create_multiple([address_hash]) == mappings
      assert Repo.aggregate(AddressIdToAddressHash, :count) == 0
      assert AddressIdToAddressHash.id_to_hash(address_id) == address_hash
    end

    test "find_or_create/1 returns a cached mapping as a loaded record" do
      address_hash = address_hash()

      created = AddressIdToAddressHash.find_or_create(address_hash)

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.find_or_create(address_hash) == created
      assert Ecto.get_meta(created, :state) == :loaded
    end

    test "uses cached mappings inside a transaction" do
      %{address_id: address_id, address_hash: address_hash} = insert(:address_id_to_address_hash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == address_id

      Repo.delete_all(AddressIdToAddressHash)

      assert {:ok, %{^address_id => ^address_hash}} =
               Repo.transaction(fn ->
                 %{address_id: id, address_hash: hash} = AddressIdToAddressHash.find_or_create(address_hash)
                 %{id => hash}
               end)

      assert Repo.aggregate(AddressIdToAddressHash, :count) == 0
    end

    test "doesn't cache mappings read inside a transaction" do
      %{address_id: address_id, address_hash: address_hash} = insert(:address_id_to_address_hash)

      assert {:ok, ^address_id} = Repo.transaction(fn -> AddressIdToAddressHash.hash_to_id(address_hash) end)

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == nil
      assert AddressIdToAddressHash.id_to_hash(address_id) == nil
    end

    test "doesn't cache mappings created in a transaction that is rolled back" do
      address_hash = address_hash()

      assert {:error, :rolled_back} =
               Repo.transaction(fn ->
                 AddressIdToAddressHash.find_or_create(address_hash)
                 Repo.rollback(:rolled_back)
               end)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == nil

      # the mapping created again gets another id, and that one is cached
      %{address_id: address_id} = AddressIdToAddressHash.find_or_create(address_hash)

      Repo.delete_all(AddressIdToAddressHash)

      assert AddressIdToAddressHash.hash_to_id(address_hash) == address_id
    end
  end

  describe "eviction" do
    test "evicts the least recently used entries until a table is 10% below the limit" do
      start_cache(20)

      [first | others] = mappings = random_mappings(21)
      {recent, [last]} = Enum.split(others, -1)

      put_one_by_one([first | recent])

      # the access makes the first mapping the most recently used one in both tables
      assert {%{}, []} = Cache.get_ids([address_hash_of(first)])
      assert {%{}, []} = Cache.get_hashes([address_id_of(first)])

      put_one_by_one([last])
      wait_for_eviction()

      # 21 entries over the limit of 20 go down to 18: the 3 least recently used are gone
      evicted = Enum.take(recent, 3)
      kept = mappings -- evicted

      assert cached_ids(mappings) == Map.new(kept, fn {address_id, address_hash} -> {address_hash, address_id} end)
      assert cached_hashes(mappings) == Map.new(kept)
    end

    test "evicts the directions separately" do
      start_cache(2)

      [first, second, third] = mappings = random_mappings(3)

      put_one_by_one([first, second])

      # the first mapping becomes the most recently used one only by its hash
      Cache.get_ids([address_hash_of(first)])

      put_one_by_one([third])
      wait_for_eviction()

      assert cached_ids(mappings) |> Map.values() |> Enum.sort() ==
               Enum.sort([address_id_of(first), address_id_of(third)])

      assert cached_hashes(mappings) |> Map.keys() |> Enum.sort() ==
               Enum.sort([address_id_of(second), address_id_of(third)])
    end

    test "estimates the least recently used entries of a table bigger than the sample" do
      start_cache(20_000)

      mappings = random_mappings(25_000)

      # the entries of a batch are accessed in its order; a single batch casts a
      # single eviction
      put(mappings)
      wait_for_eviction()

      # 7_000 of 25_000 are expected to be evicted; the estimate is off by about 100
      {oldest, rest} = Enum.split(mappings, 6_000)
      {_around_the_cutoff, newest} = Enum.split(rest, 2_000)

      ids = cached_ids(mappings)
      hashes = cached_hashes(mappings)

      assert map_size(ids) in 17_500..18_500
      assert map_size(hashes) in 17_500..18_500
      refute Enum.any?(oldest, fn {address_id, address_hash} -> ids[address_hash] || hashes[address_id] end)
      assert Enum.all?(newest, fn {address_id, address_hash} -> ids[address_hash] && hashes[address_id] end)
    end
  end

  describe "invalidation" do
    test "hides every cached mapping, and later reads fill the cache again" do
      start_cache(100)

      [{address_id, address_hash} = mapping] = random_mappings(1)
      put([mapping])

      assert Cache.get_ids([address_hash]) == {%{address_hash => address_id}, []}

      Cache.invalidate()

      assert Cache.get_ids([address_hash]) == {%{}, [address_hash]}
      assert Cache.get_hashes([address_id]) == {%{}, [address_id]}

      put([mapping])

      assert Cache.get_ids([address_hash]) == {%{address_hash => address_id}, []}
      assert Cache.get_hashes([address_id]) == {%{address_id => address_hash}, []}
    end

    test "rejects the mappings of a read that began before it" do
      start_cache(100)

      [{address_id, address_hash} = mapping] = random_mappings(1)

      # the read begins, and the cache is invalidated while the read is under way
      read_epoch = Cache.epoch()
      Cache.invalidate()
      Cache.put([mapping], Repo, read_epoch)

      assert Cache.get_ids([address_hash]) == {%{}, [address_hash]}
      assert Cache.get_hashes([address_id]) == {%{}, [address_id]}

      # not even stored: the entries would look recently used to the eviction
      assert :ets.info(:address_hash_to_address_id_cache, :size) == 0
      assert :ets.info(:address_id_to_address_hash_cache, :size) == 0
    end

    test "a read paused before Cache.put/3 caches nothing once the cache is invalidated meanwhile" do
      # created before the cache starts, so that only the paused read could cache it
      %{address_id: address_id, address_hash: existing_hash} = AddressIdToAddressHash.find_or_create(address_hash())

      start_cache(100)
      pause_after_mapping_reads()

      for {address_hash, read} <- [
            {existing_hash, &AddressIdToAddressHash.hash_to_id/1},
            {address_hash(), &AddressIdToAddressHash.find_or_create/1}
          ] do
        test_process = self()

        reader =
          Task.async(fn ->
            Process.put(:pause_after_mapping_read, test_process)
            read.(address_hash)
          end)

        # the reader has got the mapping from the database, but hasn't cached it yet
        assert_receive {:paused, reader_process}
        Cache.invalidate()
        send(reader_process, :resume)
        Task.await(reader)

        assert Cache.get_ids([address_hash]) == {%{}, [address_hash]}
      end

      # without an invalidation in between, the same read fills the cache
      assert AddressIdToAddressHash.hash_to_id(existing_hash) == address_id
      assert Cache.get_ids([existing_hash]) == {%{existing_hash => address_id}, []}
    end

    test "is harmless while the cache isn't running" do
      assert Cache.epoch() == nil
      assert Cache.invalidate(:connection) == :ok
      assert Cache.put(random_mappings(1), Repo, nil) == :ok
    end

    test "add_invalidation_on_connect/1 invalidates before the after_connect callback the options have" do
      invalidate = {Cache, :invalidate, []}

      assert Cache.add_invalidation_on_connect(pool_size: 1) == [pool_size: 1]

      start_cache(100)

      assert Cache.add_invalidation_on_connect(pool_size: 1)[:after_connect] == invalidate
      assert Cache.add_invalidation_on_connect(after_connect: nil)[:after_connect] == invalidate

      for existing <- [fn connection -> send(connection, :existing) end, {:erlang, :send, [:existing]}] do
        after_connect = Cache.add_invalidation_on_connect(after_connect: existing)[:after_connect]
        epoch = Cache.epoch()

        # the test process stands in for the connection
        after_connect.(self())

        assert Cache.epoch() != epoch
        assert_received :existing
      end
    end

    test "Explorer.Repo and Explorer.Repo.Replica1 invalidate the cache when a connection connects" do
      put_cache_config(100)

      assert Repo.config()[:after_connect] == {Cache, :invalidate, []}
      assert Replica1.config()[:after_connect] == {Cache, :invalidate, []}
    end

    test "a connection invalidates the cache before serving a query, and connects without the cache" do
      put_cache_config(100)

      # connections of their own, outside of the sandbox
      options = Repo.config() |> Keyword.drop([:pool, :pool_size]) |> Keyword.put(:pool_size, 1)

      without_cache = start_supervised!(Supervisor.child_spec({Postgrex, options}, id: :without_cache))
      assert %{rows: [[1]]} = Postgrex.query!(without_cache, "SELECT 1", [])

      start_supervised!(Cache)
      [{_address_id, address_hash} = mapping] = random_mappings(1)
      put([mapping])

      with_cache = start_supervised!(Supervisor.child_spec({Postgrex, options}, id: :with_cache))
      assert %{rows: [[1]]} = Postgrex.query!(with_cache, "SELECT 1", [])

      # nothing to wait for: the connection serves queries only once it has invalidated the cache
      assert Cache.get_ids([address_hash]) == {%{}, [address_hash]}
    end
  end

  defp start_cache(max_size) do
    put_cache_config(max_size)
    start_supervised!(Cache)

    :ok
  end

  defp put_cache_config(max_size) do
    initial_config = Application.get_env(:explorer, AddressIdToAddressHash)

    Application.put_env(
      :explorer,
      AddressIdToAddressHash,
      Keyword.merge(initial_config || [], cache_max_size: max_size)
    )

    on_exit(fn ->
      if initial_config,
        do: Application.put_env(:explorer, AddressIdToAddressHash, initial_config),
        else: Application.delete_env(:explorer, AddressIdToAddressHash)
    end)
  end

  # Pauses the reads of mappings of the processes that ask for it, see
  # `pause_after_mapping_read/4`.
  defp pause_after_mapping_reads do
    handler_id = {__MODULE__, :pause_after_mapping_read}

    :ok =
      :telemetry.attach(handler_id, [:explorer, :repo, :query], &__MODULE__.pause_after_mapping_read/4, nil)

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  @doc false
  # Runs in the process that made the query, right after the query. A process
  # that put the test process under `:pause_after_mapping_read` stops there after
  # it has read mappings, until the test resumes it.
  def pause_after_mapping_read(_event, _measurements, %{source: "address_ids_to_address_hashes", query: query}, _) do
    with "SELECT" <> _ <- query,
         test_process when is_pid(test_process) <- Process.get(:pause_after_mapping_read) do
      send(test_process, {:paused, self()})

      receive do
        :resume -> :ok
      end
    end
  end

  def pause_after_mapping_read(_event, _measurements, _metadata, _config), do: :ok

  defp random_mappings(count) do
    Enum.map(1..count, fn address_id ->
      {address_id, %Hash{byte_count: 20, bytes: :crypto.strong_rand_bytes(20)}}
    end)
  end

  defp put(mappings), do: Cache.put(mappings, Repo, Cache.epoch())

  defp put_one_by_one(mappings), do: Enum.each(mappings, &put([&1]))

  # The eviction is cast by `Cache.put/3`, which ran in this process, so it is
  # handled before this call.
  defp wait_for_eviction, do: :sys.get_state(Cache)

  defp cached_ids(mappings) do
    {found, _missing} = mappings |> Enum.map(&address_hash_of/1) |> Cache.get_ids()
    found
  end

  defp cached_hashes(mappings) do
    {found, _missing} = mappings |> Enum.map(&address_id_of/1) |> Cache.get_hashes()
    found
  end

  defp address_id_of({address_id, _address_hash}), do: address_id
  defp address_hash_of({_address_id, address_hash}), do: address_hash
end
