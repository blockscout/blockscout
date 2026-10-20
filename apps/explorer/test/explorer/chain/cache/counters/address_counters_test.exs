# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressCountersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.Counters.AddressCounters

  setup do
    start_supervised!(AddressCounters)

    :ok
  end

  describe "fetch/1" do
    test "returns DB column values and seeds the cache" do
      address = insert(:address, transactions_count: 5, token_transfers_count: 3, gas_used: 100)

      assert %{transactions_count: 5, token_transfers_count: 3, gas_used: 100} = AddressCounters.fetch(address)

      # the second read is served from ETS: a live bump is visible on top of the seed
      AddressCounters.bump_live(address.hash.bytes, delta(transactions_count: 2))

      assert %{transactions_count: 7, token_transfers_count: 3, gas_used: 100} = AddressCounters.fetch(address)
    end

    test "returns zeros and marks the address dirty when the counters were never calculated" do
      address = insert(:address)

      assert %{transactions_count: 0, token_transfers_count: 0, gas_used: 0} = AddressCounters.fetch(address)

      :sys.get_state(AddressCounters)

      assert {[{bytes, _block_number}], _continuation} = AddressCounters.select_dirty(10)
      assert bytes == address.hash.bytes
    end
  end

  describe "compute_deltas/3" do
    test "computes per-address contributions of transactions and token transfers" do
      address_a = build(:address)
      address_b = build(:address)

      transactions = [
        %{
          block_number: 100,
          from_address_hash: address_a.hash,
          to_address_hash: address_b.hash,
          gas_used: Decimal.new(21_000)
        },
        # pending transactions are skipped
        %{block_number: nil, from_address_hash: address_a.hash, to_address_hash: address_b.hash, gas_used: nil}
      ]

      token_transfers = [
        %{block_number: 101, from_address_hash: address_b.hash, to_address_hash: address_a.hash}
      ]

      deltas = AddressCounters.compute_deltas(transactions, token_transfers)

      assert %{
               transactions_count: 1,
               token_transfers_count: 1,
               gas_in: 0,
               gas_out: 21_000,
               max_block_number: 101
             } = deltas[address_a.hash.bytes]

      assert %{
               transactions_count: 1,
               token_transfers_count: 1,
               gas_in: 21_000,
               gas_out: 0,
               max_block_number: 101
             } = deltas[address_b.hash.bytes]
    end

    test "counts a self-send once and fills both gas buckets" do
      address = build(:address)

      deltas =
        AddressCounters.compute_deltas(
          [%{block_number: 5, from_address_hash: address.hash, to_address_hash: address.hash, gas_used: 100}],
          []
        )

      assert %{transactions_count: 1, gas_in: 100, gas_out: 100} = deltas[address.hash.bytes]
    end

    test "the include? predicate excludes single contributions" do
      address_a = build(:address)
      address_b = build(:address)

      transactions = [
        %{block_number: 10, from_address_hash: address_a.hash, to_address_hash: address_b.hash, gas_used: 1},
        %{block_number: 20, from_address_hash: address_a.hash, to_address_hash: address_b.hash, gas_used: 1}
      ]

      watermarks = %{address_a.hash.bytes => 15}

      deltas =
        AddressCounters.compute_deltas(transactions, [], fn bytes, block_number ->
          case watermarks[bytes] do
            nil -> false
            watermark -> block_number <= watermark
          end
        end)

      assert %{transactions_count: 1, max_block_number: 10} = deltas[address_a.hash.bytes]
      refute Map.has_key?(deltas, address_b.hash.bytes)
    end
  end

  describe "bump_live/2" do
    test "never creates entries for addresses that are not cached" do
      address = insert(:address, transactions_count: 1, token_transfers_count: 1, gas_used: 1)

      AddressCounters.bump_live(address.hash.bytes, delta(transactions_count: 5))

      # the first read seeds from the DB columns: the bump was not applied anywhere
      assert %{transactions_count: 1} = AddressCounters.fetch(address)
    end

    test "applies the gas bucket matching the cached gas direction" do
      contract = insert(:contract_address, transactions_count: 0, token_transfers_count: 0, gas_used: 0)
      AddressCounters.fetch(contract)

      AddressCounters.bump_live(contract.hash.bytes, delta(gas_in: 30, gas_out: 7))

      assert %{gas_used: 30} = AddressCounters.fetch(contract)
    end
  end

  describe "handle_new_data/3" do
    test "bumps cached entries for live data and marks addresses dirty" do
      address = insert(:address, transactions_count: 10, token_transfers_count: 0, gas_used: 0)
      AddressCounters.fetch(address)

      transactions = [
        %{block_number: 300, from_address_hash: address.hash, to_address_hash: nil, gas_used: 55}
      ]

      AddressCounters.handle_new_data(transactions, [], true)
      :sys.get_state(AddressCounters)

      assert %{transactions_count: 11, gas_used: 55} = AddressCounters.fetch(address)
      assert {[{bytes, 300}], _continuation} = AddressCounters.select_dirty(10)
      assert bytes == address.hash.bytes
    end

    test "only marks addresses dirty for catchup data" do
      address = insert(:address, transactions_count: 10, token_transfers_count: 0, gas_used: 0)
      AddressCounters.fetch(address)

      transactions = [
        %{block_number: 300, from_address_hash: address.hash, to_address_hash: nil, gas_used: 55}
      ]

      AddressCounters.handle_new_data(transactions, [], false)
      :sys.get_state(AddressCounters)

      assert %{transactions_count: 10, gas_used: 0} = AddressCounters.fetch(address)
      assert {[{_bytes, 300}], _continuation} = AddressCounters.select_dirty(10)
    end
  end

  describe "mark_dirty/1" do
    test "is a no-op on api-only nodes" do
      initial_mode = Application.get_env(:explorer, :mode)
      Application.put_env(:explorer, :mode, :api)
      on_exit(fn -> Application.put_env(:explorer, :mode, initial_mode) end)

      AddressCounters.mark_dirty([{build(:address).hash.bytes, 10}])
      :sys.get_state(AddressCounters)

      assert AddressCounters.dirty_empty?()
    end

    test "does not create new markers above the configured cap" do
      initial_env = Application.get_env(:explorer, AddressCounters) || []
      Application.put_env(:explorer, AddressCounters, Keyword.merge(initial_env, max_dirty_markers: 1))
      on_exit(fn -> Application.put_env(:explorer, AddressCounters, initial_env) end)

      address_a = build(:address)
      address_b = build(:address)

      AddressCounters.mark_dirty([{address_a.hash.bytes, 10}])
      AddressCounters.mark_dirty([{address_b.hash.bytes, 20}])
      # already-marked addresses can still be bumped
      AddressCounters.mark_dirty([{address_a.hash.bytes, 30}])
      :sys.get_state(AddressCounters)

      assert {[{bytes, 30}], _continuation} = AddressCounters.select_dirty(10)
      assert bytes == address_a.hash.bytes
    end
  end

  describe "stats/0" do
    test "reports cached addresses and dirty markers" do
      address = insert(:address, transactions_count: 5, token_transfers_count: 0, gas_used: 0)
      AddressCounters.fetch(address)

      AddressCounters.mark_dirty([{build(:address).hash.bytes, 10}])
      :sys.get_state(AddressCounters)

      assert %{cached_addresses: 1, dirty_markers: 1, memory_bytes: memory_bytes} = AddressCounters.stats()
      assert memory_bytes > 0
    end
  end

  describe "delete_dirty_markers/2" do
    test "keeps markers above the safe block" do
      address_a = build(:address)
      address_b = build(:address)

      AddressCounters.mark_dirty([{address_a.hash.bytes, 100}, {address_b.hash.bytes, 200}])
      :sys.get_state(AddressCounters)

      AddressCounters.delete_dirty_markers([address_a.hash.bytes, address_b.hash.bytes], 150)

      assert {[{bytes, 200}], _continuation} = AddressCounters.select_dirty(10)
      assert bytes == address_b.hash.bytes
    end
  end

  describe "eviction" do
    test "drops entries not touched within the TTL" do
      initial_env = Application.get_env(:explorer, AddressCounters) || []
      Application.put_env(:explorer, AddressCounters, Keyword.merge(initial_env, ttl: 0))
      on_exit(fn -> Application.put_env(:explorer, AddressCounters, initial_env) end)

      address = insert(:address, transactions_count: 5, token_transfers_count: 0, gas_used: 0)
      AddressCounters.fetch(address)

      Process.sleep(1)
      send(Process.whereis(AddressCounters), :evict)
      :sys.get_state(AddressCounters)

      assert is_nil(AddressCounters.snapshot(address.hash.bytes))
    end
  end

  defp delta(overrides) do
    Enum.into(overrides, %{transactions_count: 0, token_transfers_count: 0, gas_in: 0, gas_out: 0, max_block_number: 0})
  end
end
