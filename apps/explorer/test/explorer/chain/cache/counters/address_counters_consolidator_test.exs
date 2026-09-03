# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressCountersConsolidatorTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.{AddressCounters, AddressCountersConsolidator, Consolidation}
  alias Explorer.Repo
  alias Explorer.Utility.CountersRefetchBlock

  describe "consolidate_addresses/2" do
    test "incrementally consolidates an address with a watermark" do
      address =
        insert(:address, transactions_count: 7, token_transfers_count: 2, gas_used: 10, counters_updated_at: 100)

      in_range_block = insert(:block, number: 150)
      above_range_block = insert(:block, number: 300)

      in_range_transaction = :transaction |> insert(from_address: address) |> with_block(in_range_block)
      :transaction |> insert(to_address: address) |> with_block(above_range_block)

      another_transaction = :transaction |> insert() |> with_block(in_range_block)

      insert(:token_transfer,
        from_address: address,
        transaction: another_transaction,
        block: in_range_block,
        block_number: in_range_block.number
      )

      AddressCountersConsolidator.consolidate_addresses([address.hash], 200)

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 8
      assert reloaded.token_transfers_count == 3
      assert reloaded.gas_used == 10 + Decimal.to_integer(in_range_transaction.gas_used)
      assert reloaded.counters_updated_at == 200
    end

    test "recalculates an address without a watermark from scratch, replacing stale values" do
      address = insert(:address, transactions_count: 1000, token_transfers_count: 1000, gas_used: 1000)

      block = insert(:block, number: 50)
      transaction = :transaction |> insert(from_address: address) |> with_block(block)

      AddressCountersConsolidator.consolidate_addresses([address.hash], 200)

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 1
      assert reloaded.token_transfers_count == 0
      assert reloaded.gas_used == Decimal.to_integer(transaction.gas_used)
      assert reloaded.counters_updated_at == 200
    end

    test "skips addresses already consolidated at or above the safe block" do
      address = insert(:address, transactions_count: 7, counters_updated_at: 300)

      block = insert(:block, number: 150)
      :transaction |> insert(from_address: address) |> with_block(block)

      AddressCountersConsolidator.consolidate_addresses([address.hash], 200)

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 7
      assert reloaded.counters_updated_at == 300
    end

    test "accumulates incoming gas for contracts and outgoing gas for EOAs with delegated code" do
      contract = insert(:contract_address, counters_updated_at: 100)

      eoa_with_code =
        insert(:address,
          contract_code: "0xef01001111111111111111111111111111111111111111",
          counters_updated_at: 100
        )

      block = insert(:block, number: 150)

      incoming_to_contract = :transaction |> insert(to_address: contract) |> with_block(block)
      :transaction |> insert(from_address: contract) |> with_block(insert(:block, number: 151))

      incoming_to_eoa = :transaction |> insert(to_address: eoa_with_code) |> with_block(insert(:block, number: 152))
      outgoing_from_eoa = :transaction |> insert(from_address: eoa_with_code) |> with_block(insert(:block, number: 153))

      _ = incoming_to_eoa

      AddressCountersConsolidator.consolidate_addresses([contract.hash, eoa_with_code.hash], 200)

      assert Repo.get(Address, contract.hash).gas_used == Decimal.to_integer(incoming_to_contract.gas_used)
      assert Repo.get(Address, eoa_with_code.hash).gas_used == Decimal.to_integer(outgoing_from_eoa.gas_used)
    end
  end

  describe "safe_block/0" do
    setup do
      initial_env = Application.get_env(:explorer, Consolidation) || []

      Application.put_env(
        :explorer,
        Consolidation,
        Keyword.merge(initial_env, safe_block_lag: 0)
      )

      on_exit(fn -> Application.put_env(:explorer, Consolidation, initial_env) end)

      :ok
    end

    test "returns the lagged chain head" do
      insert(:block, number: 0)
      insert(:block, number: 100)

      assert AddressCountersConsolidator.safe_block() == 100
    end

    test "is nil while the chain is not indexed down to the first block" do
      insert(:block, number: 100)

      assert AddressCountersConsolidator.safe_block() == nil
    end

    test "is capped below the lowest missing block range" do
      insert(:block, number: 0)
      insert(:block, number: 100)
      insert(:missing_block_range, from_number: 60, to_number: 50)

      assert AddressCountersConsolidator.safe_block() == 49
    end

    test "is capped below the lowest block pending a re-fetch counter correction" do
      insert(:block, number: 0)
      insert(:block, number: 100)
      Repo.insert!(%CountersRefetchBlock{block_number: 30})

      assert AddressCountersConsolidator.safe_block() == 29
    end
  end

  describe "consolidation cycle process" do
    test "the process stays responsive while a cycle runs and reports it in its state" do
      pid = start_supervised!(AddressCountersConsolidator)

      send(pid, :consolidate)

      # the cycle runs in a task, so the process answers immediately
      assert %{cycle_task: _, cycle_started_at: _, last_cycle_finished_at: _} = :sys.get_state(pid, 1_000)

      wait_for_results(fn ->
        case :sys.get_state(pid, 1_000) do
          %{cycle_task: nil, last_cycle_finished_at: %DateTime{}} -> :ok
          _ -> raise Ecto.NoResultsError, queryable: "cycle completion"
        end
      end)
    end
  end

  describe "consolidate/0" do
    setup do
      initial_env = Application.get_env(:explorer, Consolidation) || []

      Application.put_env(
        :explorer,
        Consolidation,
        Keyword.merge(initial_env, safe_block_lag: 0)
      )

      on_exit(fn -> Application.put_env(:explorer, Consolidation, initial_env) end)

      start_supervised!(AddressCounters)

      :ok
    end

    test "consolidates dirty addresses and clears their markers" do
      address = insert(:address, transactions_count: 1, token_transfers_count: 0, gas_used: 0, counters_updated_at: 10)

      insert(:block, number: 0)
      block = insert(:block, number: 100)
      :transaction |> insert(from_address: address) |> with_block(block)

      AddressCounters.mark_dirty([{address.hash.bytes, 100}])
      :sys.get_state(AddressCounters)

      AddressCountersConsolidator.consolidate()

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 2
      assert reloaded.counters_updated_at == 100
      assert AddressCounters.dirty_empty?()
    end

    test "keeps markers above the safe block" do
      address = insert(:address, transactions_count: 1, token_transfers_count: 0, gas_used: 0, counters_updated_at: 10)

      insert(:block, number: 0)
      insert(:block, number: 100)

      AddressCounters.mark_dirty([{address.hash.bytes, 500}])
      :sys.get_state(AddressCounters)

      AddressCountersConsolidator.consolidate()

      assert Repo.get(Address, address.hash).counters_updated_at == 100
      refute AddressCounters.dirty_empty?()
    end

    test "settles re-fetched blocks: adds the re-imported content below the watermark and drops the queue rows" do
      address = insert(:address, transactions_count: 5, token_transfers_count: 0, gas_used: 0, counters_updated_at: 100)

      reimported_block = insert(:block, number: 50, refetch_needed: false)
      transaction = :transaction |> insert(from_address: address) |> with_block(reimported_block)

      insert(:block, number: 100)
      Repo.insert!(%CountersRefetchBlock{block_number: 50})

      AddressCountersConsolidator.consolidate()

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 6
      assert reloaded.gas_used == Decimal.to_integer(transaction.gas_used)
      # settling a covered block does not move the watermark
      assert reloaded.counters_updated_at == 100
      assert Repo.aggregate(CountersRefetchBlock, :count) == 0
    end

    test "does not settle blocks still awaiting their re-fetch" do
      insert(:block, number: 50, refetch_needed: true)
      insert(:block, number: 100)
      Repo.insert!(%CountersRefetchBlock{block_number: 50})

      AddressCountersConsolidator.consolidate()

      assert Repo.aggregate(CountersRefetchBlock, :count) == 1
    end

    test "does not settle blocks still covered by a missing range" do
      # refetch_needed already flipped, but the re-import has not fully
      # completed yet (the missing range row is only removed afterwards)
      insert(:block, number: 50, refetch_needed: false)
      insert(:block, number: 100)
      insert(:missing_block_range, from_number: 50, to_number: 50)
      Repo.insert!(%CountersRefetchBlock{block_number: 50})

      AddressCountersConsolidator.consolidate()

      assert Repo.aggregate(CountersRefetchBlock, :count) == 1
    end
  end

  describe "apply_covered_deltas/4" do
    test "applies negative deltas only for blocks covered by the address watermark" do
      address =
        insert(:address, transactions_count: 5, token_transfers_count: 3, gas_used: 100, counters_updated_at: 100)

      transactions = [
        %{block_number: 50, from_address_hash: address.hash, to_address_hash: nil, gas_used: 30},
        # above the watermark: never counted, must not be subtracted
        %{block_number: 150, from_address_hash: address.hash, to_address_hash: nil, gas_used: 30}
      ]

      token_transfers = [
        %{block_number: 50, from_address_hash: address.hash, to_address_hash: nil}
      ]

      [updated_bytes] = AddressCountersConsolidator.apply_covered_deltas(transactions, token_transfers, :negative)

      assert updated_bytes == address.hash.bytes

      reloaded = Repo.get(Address, address.hash)

      assert reloaded.transactions_count == 4
      assert reloaded.token_transfers_count == 2
      assert reloaded.gas_used == 70
      assert reloaded.counters_updated_at == 100
    end

    test "skips addresses without a watermark" do
      address = insert(:address, transactions_count: 5)

      transactions = [%{block_number: 50, from_address_hash: address.hash, to_address_hash: nil, gas_used: 30}]

      assert AddressCountersConsolidator.apply_covered_deltas(transactions, [], :positive) == []
      assert Repo.get(Address, address.hash).transactions_count == 5
    end
  end
end
