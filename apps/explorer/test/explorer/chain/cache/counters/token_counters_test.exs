# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.TokenCountersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.Counters.TokenCounters

  setup do
    start_supervised!(TokenCounters)

    :ok
  end

  describe "fetch/1" do
    test "returns the transfer_count column value and seeds the cache" do
      token = insert(:token, transfer_count: 5, counters_updated_at: 100)

      assert TokenCounters.fetch(token) == 5

      # the second read is served from ETS: a live bump is visible on top
      TokenCounters.bump_live(token.contract_address_hash.bytes, %{transfer_count: 2, max_block_number: 101})

      assert TokenCounters.fetch(token) == 7
    end

    test "returns zero and marks the token dirty when the counter was never calculated" do
      token = insert(:token, transfer_count: nil)

      assert TokenCounters.fetch(token) == 0

      :sys.get_state(TokenCounters)

      assert {[{bytes, _block_number}], _continuation} = TokenCounters.select_dirty(10)
      assert bytes == token.contract_address_hash.bytes
    end
  end

  describe "compute_transfer_deltas/2" do
    test "computes per-token deltas skipping rows without a block number" do
      token_a = insert(:token)
      token_b = insert(:token)

      token_transfers = [
        %{token_contract_address_hash: token_a.contract_address_hash, block_number: 100},
        %{token_contract_address_hash: token_a.contract_address_hash, block_number: 105},
        %{token_contract_address_hash: token_b.contract_address_hash, block_number: 101},
        %{token_contract_address_hash: token_a.contract_address_hash, block_number: nil}
      ]

      deltas = TokenCounters.compute_transfer_deltas(token_transfers)

      assert %{transfer_count: 2, max_block_number: 105} = deltas[token_a.contract_address_hash.bytes]
      assert %{transfer_count: 1, max_block_number: 101} = deltas[token_b.contract_address_hash.bytes]
    end

    test "the include? predicate excludes single contributions" do
      token = insert(:token)

      token_transfers = [
        %{token_contract_address_hash: token.contract_address_hash, block_number: 10},
        %{token_contract_address_hash: token.contract_address_hash, block_number: 20}
      ]

      deltas = TokenCounters.compute_transfer_deltas(token_transfers, fn _bytes, block_number -> block_number <= 15 end)

      assert %{transfer_count: 1, max_block_number: 10} = deltas[token.contract_address_hash.bytes]
    end
  end

  describe "bump_live/2" do
    test "never creates entries for tokens that are not cached" do
      token = insert(:token, transfer_count: 1, counters_updated_at: 100)

      TokenCounters.bump_live(token.contract_address_hash.bytes, %{transfer_count: 5, max_block_number: 101})

      # the first read seeds from the DB column: the bump was not applied anywhere
      assert TokenCounters.fetch(token) == 1
    end
  end

  describe "handle_new_data/2" do
    test "bumps cached entries for live data and marks tokens dirty" do
      token = insert(:token, transfer_count: 10, counters_updated_at: 100)
      TokenCounters.fetch(token)

      token_transfers = [%{token_contract_address_hash: token.contract_address_hash, block_number: 300}]

      TokenCounters.handle_new_data(token_transfers, true)
      :sys.get_state(TokenCounters)

      assert TokenCounters.fetch(token) == 11
      assert {[{bytes, 300}], _continuation} = TokenCounters.select_dirty(10)
      assert bytes == token.contract_address_hash.bytes
    end

    test "only marks tokens dirty for catchup data" do
      token = insert(:token, transfer_count: 10, counters_updated_at: 100)
      TokenCounters.fetch(token)

      token_transfers = [%{token_contract_address_hash: token.contract_address_hash, block_number: 300}]

      TokenCounters.handle_new_data(token_transfers, false)
      :sys.get_state(TokenCounters)

      assert TokenCounters.fetch(token) == 10
      assert {[{_bytes, 300}], _continuation} = TokenCounters.select_dirty(10)
    end
  end

  describe "mark_dirty/1" do
    test "is a no-op on api-only nodes" do
      initial_mode = Application.get_env(:explorer, :mode)
      Application.put_env(:explorer, :mode, :api)
      on_exit(fn -> Application.put_env(:explorer, :mode, initial_mode) end)

      TokenCounters.mark_dirty([{insert(:token).contract_address_hash.bytes, 10}])
      :sys.get_state(TokenCounters)

      assert TokenCounters.dirty_empty?()
    end

    test "does not create new markers above the configured cap" do
      initial_env = Application.get_env(:explorer, TokenCounters) || []
      Application.put_env(:explorer, TokenCounters, Keyword.merge(initial_env, max_dirty_markers: 1))
      on_exit(fn -> Application.put_env(:explorer, TokenCounters, initial_env) end)

      token_a = insert(:token)
      token_b = insert(:token)

      TokenCounters.mark_dirty([{token_a.contract_address_hash.bytes, 10}])
      TokenCounters.mark_dirty([{token_b.contract_address_hash.bytes, 20}])
      # already-marked tokens can still be bumped
      TokenCounters.mark_dirty([{token_a.contract_address_hash.bytes, 30}])
      :sys.get_state(TokenCounters)

      assert {[{bytes, 30}], _continuation} = TokenCounters.select_dirty(10)
      assert bytes == token_a.contract_address_hash.bytes
    end
  end

  describe "delete_dirty_markers/2" do
    test "keeps markers above the safe block" do
      token_a = insert(:token)
      token_b = insert(:token)

      TokenCounters.mark_dirty([{token_a.contract_address_hash.bytes, 100}, {token_b.contract_address_hash.bytes, 200}])
      :sys.get_state(TokenCounters)

      TokenCounters.delete_dirty_markers(
        [token_a.contract_address_hash.bytes, token_b.contract_address_hash.bytes],
        150
      )

      assert {[{bytes, 200}], _continuation} = TokenCounters.select_dirty(10)
      assert bytes == token_b.contract_address_hash.bytes
    end
  end

  describe "eviction" do
    test "drops entries not touched within the TTL" do
      initial_env = Application.get_env(:explorer, TokenCounters) || []
      Application.put_env(:explorer, TokenCounters, Keyword.merge(initial_env, ttl: 0))
      on_exit(fn -> Application.put_env(:explorer, TokenCounters, initial_env) end)

      token = insert(:token, transfer_count: 5, counters_updated_at: 100)
      TokenCounters.fetch(token)

      Process.sleep(1)
      send(Process.whereis(TokenCounters), :evict)
      :sys.get_state(TokenCounters)

      assert is_nil(TokenCounters.snapshot(token.contract_address_hash.bytes))
    end
  end
end
