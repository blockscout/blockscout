# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.TokenCountersConsolidatorTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.Counters.{Consolidation, TokenCounters, TokenCountersConsolidator}
  alias Explorer.Chain.Token
  alias Explorer.Repo
  alias Explorer.Utility.CountersRefetchBlock

  describe "consolidate_tokens/2" do
    test "incrementally consolidates a token with a watermark" do
      token = insert(:token, transfer_count: 7, holder_count: 3, counters_updated_at: 100)

      in_range_block = insert(:block, number: 150)
      above_range_block = insert(:block, number: 300)

      insert_transfer(token, in_range_block)
      insert_transfer(token, above_range_block)

      TokenCountersConsolidator.consolidate_tokens([token.contract_address_hash], 200)

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 8
      # holders are delta-maintained, the incremental path leaves them alone
      assert reloaded.holder_count == 3
      assert reloaded.counters_updated_at == 200
    end

    test "recalculates a token without a watermark from scratch, replacing stale values" do
      token = insert(:token, transfer_count: 1000, holder_count: 1000)

      block = insert(:block, number: 50)
      insert_transfer(token, block)

      insert(:address_current_token_balance, token_contract_address_hash: token.contract_address_hash, value: 10)
      insert(:address_current_token_balance, token_contract_address_hash: token.contract_address_hash, value: 20)

      TokenCountersConsolidator.consolidate_tokens([token.contract_address_hash], 200)

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 1
      assert reloaded.holder_count == 2
      assert reloaded.counters_updated_at == 200
    end

    test "the holder recount excludes the burn address, counts any ERC-7984 row and distinct holders once" do
      token = insert(:token, holder_count: nil)

      burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")

      insert(:address_current_token_balance,
        address: burn_address,
        token_contract_address_hash: token.contract_address_hash,
        value: 100
      )

      confidential_holder = insert(:address)

      insert(:address_current_token_balance,
        address: confidential_holder,
        token_contract_address_hash: token.contract_address_hash,
        value: 0,
        token_type: "ERC-7984"
      )

      multi_row_holder = insert(:address)

      insert(:address_current_token_balance,
        address: multi_row_holder,
        token_contract_address_hash: token.contract_address_hash,
        token_id: 1,
        token_type: "ERC-1155",
        value: 5
      )

      insert(:address_current_token_balance,
        address: multi_row_holder,
        token_contract_address_hash: token.contract_address_hash,
        token_id: 2,
        token_type: "ERC-1155",
        value: 7
      )

      TokenCountersConsolidator.consolidate_tokens([token.contract_address_hash], 200)

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      # confidential holder + the multi-row holder counted once; burn excluded
      assert reloaded.holder_count == 2
    end

    test "a drifted holder_count is normalized to the recount" do
      token = insert(:token, transfer_count: 0, holder_count: 100)

      insert(:address_current_token_balance, token_contract_address_hash: token.contract_address_hash, value: 10)

      TokenCountersConsolidator.consolidate_tokens([token.contract_address_hash], 200)

      assert Repo.get_by(Token, contract_address_hash: token.contract_address_hash).holder_count == 1
    end

    test "skips tokens already consolidated at or above the safe block" do
      token = insert(:token, transfer_count: 7, counters_updated_at: 300)

      block = insert(:block, number: 150)
      insert_transfer(token, block)

      TokenCountersConsolidator.consolidate_tokens([token.contract_address_hash], 200)

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 7
      assert reloaded.counters_updated_at == 300
    end
  end

  describe "consolidation cycle process" do
    test "the process stays responsive while a cycle runs and reports it in its state" do
      pid = start_supervised!(TokenCountersConsolidator)

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

      start_supervised!(TokenCounters)

      :ok
    end

    test "consolidates dirty tokens and clears their markers" do
      token = insert(:token, transfer_count: 1, counters_updated_at: 10)

      insert(:block, number: 0)
      block = insert(:block, number: 100)
      insert_transfer(token, block)

      TokenCounters.mark_dirty([{token.contract_address_hash.bytes, 100}])
      :sys.get_state(TokenCounters)

      TokenCountersConsolidator.consolidate()

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 2
      assert reloaded.counters_updated_at == 100
      assert TokenCounters.dirty_empty?()
    end

    test "keeps markers above the safe block" do
      token = insert(:token, transfer_count: 1, counters_updated_at: 10)

      insert(:block, number: 0)
      insert(:block, number: 100)

      TokenCounters.mark_dirty([{token.contract_address_hash.bytes, 500}])
      :sys.get_state(TokenCounters)

      TokenCountersConsolidator.consolidate()

      assert Repo.get_by(Token, contract_address_hash: token.contract_address_hash).counters_updated_at == 100
      refute TokenCounters.dirty_empty?()
    end

    test "settles re-fetched blocks: adds the re-imported transfers below the watermark and drops the queue rows" do
      token = insert(:token, transfer_count: 5, counters_updated_at: 100)

      reimported_block = insert(:block, number: 50, refetch_needed: false)
      insert_transfer(token, reimported_block)

      insert(:block, number: 100)
      Repo.insert!(%CountersRefetchBlock{block_number: 50})

      TokenCountersConsolidator.consolidate()

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 6
      # settling a covered block does not move the watermark
      assert reloaded.counters_updated_at == 100
      assert Repo.aggregate(CountersRefetchBlock, :count) == 0
    end
  end

  describe "apply_covered_transfer_deltas/3" do
    test "applies negative deltas only for blocks covered by the token watermark" do
      token = insert(:token, transfer_count: 5, counters_updated_at: 100)

      token_transfers = [
        %{token_contract_address_hash: token.contract_address_hash, block_number: 50},
        # above the watermark: never counted, must not be subtracted
        %{token_contract_address_hash: token.contract_address_hash, block_number: 150}
      ]

      [updated_bytes] = TokenCountersConsolidator.apply_covered_transfer_deltas(token_transfers, :negative)

      assert updated_bytes == token.contract_address_hash.bytes

      reloaded = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert reloaded.transfer_count == 4
      assert reloaded.counters_updated_at == 100
    end

    test "skips tokens without a watermark" do
      token = insert(:token, transfer_count: 5)

      token_transfers = [%{token_contract_address_hash: token.contract_address_hash, block_number: 50}]

      assert TokenCountersConsolidator.apply_covered_transfer_deltas(token_transfers, :positive) == []
      assert Repo.get_by(Token, contract_address_hash: token.contract_address_hash).transfer_count == 5
    end
  end

  describe "reset_covered_watermarks/2" do
    test "resets only tokens whose watermark covers the block and marks them dirty" do
      start_supervised!(TokenCounters)

      covered_token = insert(:token, counters_updated_at: 100)
      fresh_token = insert(:token, counters_updated_at: 30)

      reset_bytes =
        TokenCountersConsolidator.reset_covered_watermarks(%{
          covered_token.contract_address_hash.bytes => 50,
          fresh_token.contract_address_hash.bytes => 50
        })

      assert reset_bytes == [covered_token.contract_address_hash.bytes]
      assert is_nil(Repo.get_by(Token, contract_address_hash: covered_token.contract_address_hash).counters_updated_at)
      assert Repo.get_by(Token, contract_address_hash: fresh_token.contract_address_hash).counters_updated_at == 30

      # the recalculation of the reset token is scheduled
      :sys.get_state(TokenCounters)
      assert {[{marked_bytes, _block_number}], _continuation} = TokenCounters.select_dirty(10)
      assert marked_bytes == covered_token.contract_address_hash.bytes
    end
  end

  defp insert_transfer(token, block) do
    transaction = :transaction |> insert() |> with_block(block)

    insert(:token_transfer,
      transaction: transaction,
      block: block,
      block_number: block.number,
      token_contract_address: token.contract_address
    )
  end
end
