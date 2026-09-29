# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.UIMultiplierChangeTest do
  use Explorer.DataCase

  import ExUnit.CaptureLog

  alias Explorer.Chain.Token.UIMultiplierChange
  alias Explorer.PagingOptions

  @one Decimal.new("1000000000000000000")
  @two Decimal.new("2000000000000000000")
  @four Decimal.new("4000000000000000000")
  @eight Decimal.new("8000000000000000000")

  defp change(block_number, log_index, old, new, effective_at) do
    %UIMultiplierChange{
      block_number: block_number,
      log_index: log_index,
      old_multiplier: old,
      new_multiplier: new,
      effective_at: effective_at
    }
  end

  describe "at/4" do
    test "is nil when nothing is known about the token" do
      refute UIMultiplierChange.at([], 100, 0, ~U[2026-09-01 00:00:00Z])
    end

    test "is nil when the moment of the amount is unknown" do
      # without it there is no telling whether a scheduled change had matured,
      # and guessing would be silently wrong
      changes = [change(100, 0, @one, @two, ~U[2026-09-01 00:00:00Z])]

      refute UIMultiplierChange.at(changes, 200, 0, nil)
    end

    test "resolves an amount older than every known change to the value the earliest one replaced" do
      changes = [change(100, 0, @one, @two, ~U[2026-09-01 00:00:00Z])]

      assert UIMultiplierChange.at(changes, 50, 0, ~U[2026-08-01 00:00:00Z]) == @one
    end

    test "keeps the old value between the announcement and the moment it takes effect" do
      changes = [change(100, 0, @one, @two, ~U[2026-09-01 00:00:00Z])]

      assert UIMultiplierChange.at(changes, 150, 0, ~U[2026-08-31 23:59:59Z]) == @one
    end

    test "switches to the new value from the moment it takes effect" do
      changes = [change(100, 0, @one, @two, ~U[2026-09-01 00:00:00Z])]

      assert UIMultiplierChange.at(changes, 150, 0, ~U[2026-09-01 00:00:00Z]) == @two
      assert UIMultiplierChange.at(changes, 150, 0, ~U[2026-09-02 00:00:00Z]) == @two
    end

    test "accounts for a change announced earlier in the very same block" do
      changes = [change(100, 3, @one, @two, ~U[2026-08-01 00:00:00Z])]

      assert UIMultiplierChange.at(changes, 100, 2, ~U[2026-09-01 00:00:00Z]) == @one
      assert UIMultiplierChange.at(changes, 100, 4, ~U[2026-09-01 00:00:00Z]) == @two
    end

    test "never applies a change that was superseded before it matured" do
      changes = [
        # scheduled for October, but replaced in block 200 before that
        change(100, 0, @one, @eight, ~U[2026-10-01 00:00:00Z]),
        change(200, 0, @one, @two, ~U[2026-09-01 00:00:00Z])
      ]

      assert UIMultiplierChange.at(changes, 300, 0, ~U[2026-09-15 00:00:00Z]) == @two
      assert UIMultiplierChange.at(changes, 300, 0, ~U[2026-11-01 00:00:00Z]) == @two
    end

    test "walks a chain of matured changes" do
      changes = [
        change(100, 0, @one, @two, ~U[2026-03-01 00:00:00Z]),
        change(200, 0, @two, @four, ~U[2026-06-01 00:00:00Z]),
        change(300, 0, @four, @eight, ~U[2026-09-01 00:00:00Z])
      ]

      assert UIMultiplierChange.at(changes, 150, 0, ~U[2026-04-01 00:00:00Z]) == @two
      assert UIMultiplierChange.at(changes, 250, 0, ~U[2026-07-01 00:00:00Z]) == @four
      assert UIMultiplierChange.at(changes, 350, 0, ~U[2026-10-01 00:00:00Z]) == @eight
    end
  end

  describe "put_ui_multipliers/2" do
    test "fills the multiplier each transfer saw, not the one in force now" do
      token = insert(:token, ui_multiplier: @four, new_ui_multiplier: @four, ui_multiplier_effective_at: nil)

      insert(:token_ui_multiplier_change,
        token: token,
        block_number: 100,
        log_index: 0,
        old_multiplier: @two,
        new_multiplier: @four,
        effective_at: ~U[2026-06-01 00:00:00.000000Z]
      )

      before_split = transfer_at(token, ~U[2026-05-01 00:00:00.000000Z], 150)
      after_split = transfer_at(token, ~U[2026-07-01 00:00:00.000000Z], 160)

      assert [resolved_before, resolved_after] =
               UIMultiplierChange.put_ui_multipliers([before_split, after_split])

      assert resolved_before.ui_multiplier == @two
      assert resolved_after.ui_multiplier == @four
    end

    test "leaves transfers of tokens without ERC-8056 support alone" do
      token = insert(:token)
      transfer = transfer_at(token, ~U[2026-07-01 00:00:00.000000Z], 150)

      assert [resolved] = UIMultiplierChange.put_ui_multipliers([transfer])

      refute resolved.ui_multiplier
    end

    test "passes nil entries through" do
      assert UIMultiplierChange.put_ui_multipliers([nil]) == [nil]
    end

    test "resolves a transfer that comes without its block or transaction" do
      # the shape the transaction endpoints hand over: the page carries the
      # transaction once, so its transfers are loaded with nothing but the token
      token = insert(:token, ui_multiplier: @four, new_ui_multiplier: @four, ui_multiplier_effective_at: nil)

      insert(:token_ui_multiplier_change,
        token: token,
        block_number: 100,
        log_index: 0,
        old_multiplier: @two,
        new_multiplier: @four,
        effective_at: ~U[2026-06-01 00:00:00.000000Z]
      )

      transfer = %{transfer_at(token, ~U[2026-05-01 00:00:00.000000Z], 150) | block: nil, transaction: nil}

      assert [resolved] = UIMultiplierChange.put_ui_multipliers([transfer])

      assert resolved.ui_multiplier == @two
    end

    test "ignores a change whose block lost consensus" do
      token = insert(:token, ui_multiplier: @four)
      reorged = insert(:block, number: 100, consensus: false)

      insert(:token_ui_multiplier_change,
        token: token,
        block: reorged,
        block_number: reorged.number,
        log_index: 0,
        old_multiplier: @two,
        new_multiplier: @four,
        effective_at: ~U[2026-06-01 00:00:00.000000Z]
      )

      transfer = transfer_at(token, ~U[2026-07-01 00:00:00.000000Z], 150)

      assert [resolved] = UIMultiplierChange.put_ui_multipliers([transfer])

      refute resolved.ui_multiplier
    end

    test "refuses to resolve a token whose history outgrew the cap" do
      token = insert(:token, ui_multiplier: @four)
      block = insert(:block, number: 100)
      now = DateTime.utc_now()

      rows =
        Enum.map(1..1001, fn log_index ->
          %{
            token_contract_address_hash: token.contract_address_hash,
            block_number: block.number,
            block_hash: block.hash,
            log_index: log_index,
            old_multiplier: @two,
            new_multiplier: @four,
            effective_at: ~U[2026-06-01 00:00:00.000000Z],
            inserted_at: now,
            updated_at: now
          }
        end)

      Repo.insert_all(UIMultiplierChange, rows)

      transfer = transfer_at(token, ~U[2026-07-01 00:00:00.000000Z], 150)

      assert [resolved] = UIMultiplierChange.put_ui_multipliers([transfer])

      refute resolved.ui_multiplier
    end
  end

  describe "insert_changes/1" do
    test "records a change whose hashes are still the strings the log carried" do
      # the shape `Indexer.Transform.TokenTransfers` hands over: both hashes are
      # taken straight off the log and have not been cast yet, while
      # `insert_all/3` dumps rather than casts and would raise on them
      token = insert(:token)
      block = insert(:block, number: 100)

      UIMultiplierChange.insert_changes([
        %{
          token_contract_address_hash: to_string(token.contract_address_hash),
          block_number: block.number,
          block_hash: to_string(block.hash),
          log_index: 5,
          old_multiplier: @two,
          new_multiplier: @four,
          effective_at: ~U[2026-09-01 00:00:00.000000Z]
        }
      ])

      assert change =
               Repo.get_by(UIMultiplierChange,
                 token_contract_address_hash: token.contract_address_hash,
                 block_number: block.number,
                 log_index: 5
               )

      assert change.block_hash == block.hash
      assert Decimal.equal?(change.new_multiplier, @four)
    end

    test "records the transaction the log came from" do
      token = insert(:token)
      block = insert(:block, number: 100)
      transaction = :transaction |> insert() |> with_block(block)

      UIMultiplierChange.insert_changes([
        %{
          token_contract_address_hash: to_string(token.contract_address_hash),
          block_number: block.number,
          block_hash: to_string(block.hash),
          transaction_hash: to_string(transaction.hash),
          log_index: 5,
          old_multiplier: @two,
          new_multiplier: @four,
          effective_at: ~U[2026-09-01 00:00:00.000000Z]
        }
      ])

      assert change =
               Repo.get_by(UIMultiplierChange,
                 token_contract_address_hash: token.contract_address_hash,
                 block_number: block.number,
                 log_index: 5
               )

      assert change.transaction_hash == transaction.hash
    end

    test "records a change of a log that belongs to no transaction" do
      token = insert(:token)
      block = insert(:block, number: 100)

      UIMultiplierChange.insert_changes([
        %{
          token_contract_address_hash: token.contract_address_hash,
          block_number: block.number,
          block_hash: block.hash,
          transaction_hash: nil,
          log_index: 5,
          old_multiplier: @two,
          new_multiplier: @four,
          effective_at: ~U[2026-09-01 00:00:00.000000Z]
        }
      ])

      assert change =
               Repo.get_by(UIMultiplierChange,
                 token_contract_address_hash: token.contract_address_hash,
                 block_number: block.number,
                 log_index: 5
               )

      refute change.transaction_hash
    end

    test "drops a change carrying an unparsable hash instead of taking the caller down" do
      block = insert(:block, number: 100)

      log =
        capture_log(fn ->
          assert UIMultiplierChange.insert_changes([
                   %{
                     token_contract_address_hash: "not a hash",
                     block_number: block.number,
                     block_hash: to_string(block.hash),
                     log_index: 5,
                     old_multiplier: @two,
                     new_multiplier: @four,
                     effective_at: ~U[2026-09-01 00:00:00.000000Z]
                   }
                 ]) == {0, nil}
        end)

      assert log =~ "unparsable hash"
      assert Repo.all(UIMultiplierChange) == []
    end

    test "stops recording once a token reached the cap" do
      token = insert(:token)
      block = insert(:block, number: 100)
      now = DateTime.utc_now()

      rows =
        Enum.map(1..1000, fn log_index ->
          %{
            token_contract_address_hash: token.contract_address_hash,
            block_number: block.number,
            block_hash: block.hash,
            log_index: log_index,
            old_multiplier: @two,
            new_multiplier: @four,
            effective_at: ~U[2026-06-01 00:00:00.000000Z],
            inserted_at: now,
            updated_at: now
          }
        end)

      Repo.insert_all(UIMultiplierChange, rows)

      UIMultiplierChange.insert_changes([
        %{
          token_contract_address_hash: token.contract_address_hash,
          block_number: block.number,
          block_hash: block.hash,
          log_index: 2000,
          old_multiplier: @two,
          new_multiplier: @one,
          effective_at: ~U[2026-09-01 00:00:00.000000Z]
        }
      ])

      refute Repo.get_by(UIMultiplierChange,
               token_contract_address_hash: token.contract_address_hash,
               block_number: block.number,
               log_index: 2000
             )
    end
  end

  describe "at_end_of_transaction/3" do
    test "accounts for a change the transaction announced after its last known log" do
      # a balance is the state the whole transaction leaves behind, so a change
      # the transaction itself announced counts even when it was announced after
      # the transfer the balance was derived from
      transaction = transaction_at(~U[2026-09-01 00:00:00Z], 100)

      changes = [%{change(100, 9, @one, @two, ~U[2026-08-01 00:00:00Z]) | transaction_hash: transaction.hash}]

      assert UIMultiplierChange.at_end_of_transaction(changes, transaction, 3) == @two
    end

    test "ignores a change announced by a later transaction of the same block" do
      transaction = transaction_at(~U[2026-09-01 00:00:00Z], 100)
      changes = [change(100, 9, @one, @two, ~U[2026-08-01 00:00:00Z])]

      assert UIMultiplierChange.at_end_of_transaction(changes, transaction, 3) == @one
    end

    test "accounts for a change announced by an earlier transaction of the same block" do
      transaction = transaction_at(~U[2026-09-01 00:00:00Z], 100)
      changes = [change(100, 1, @one, @two, ~U[2026-08-01 00:00:00Z])]

      assert UIMultiplierChange.at_end_of_transaction(changes, transaction, 3) == @two
    end

    test "keeps the old value of a change the transaction announced but which has not matured" do
      transaction = transaction_at(~U[2026-09-01 00:00:00Z], 100)

      changes = [%{change(100, 9, @one, @two, ~U[2026-10-01 00:00:00Z]) | transaction_hash: transaction.hash}]

      assert UIMultiplierChange.at_end_of_transaction(changes, transaction, 3) == @one
    end
  end

  describe "paginated_for_token/2" do
    test "lists the history of one token, newest first, with the moment of each announcement" do
      token = insert(:token, ui_multiplier: @four)
      transaction = transaction_at(~U[2026-03-01 00:00:00.000000Z], 100)

      insert(:token_ui_multiplier_change,
        token: token,
        block: transaction.block,
        block_number: 100,
        log_index: 0,
        transaction_hash: transaction.hash,
        old_multiplier: @one,
        new_multiplier: @two,
        effective_at: ~U[2026-03-01 00:00:00.000000Z]
      )

      later = insert(:block, number: 200, timestamp: ~U[2026-06-01 00:00:00.000000Z])

      insert(:token_ui_multiplier_change,
        token: token,
        block: later,
        block_number: 200,
        log_index: 7,
        old_multiplier: @two,
        new_multiplier: @four,
        effective_at: ~U[2026-06-01 00:00:00.000000Z]
      )

      assert [newest, oldest] = UIMultiplierChange.paginated_for_token(token.contract_address_hash)

      assert %{block_number: 200, log_index: 7, transaction_hash: nil} = newest
      assert newest.timestamp == ~U[2026-06-01 00:00:00.000000Z]
      assert newest.block_hash == later.hash
      assert Decimal.equal?(newest.new_multiplier, @four)

      assert %{block_number: 100, log_index: 0} = oldest
      assert oldest.transaction_hash == transaction.hash
      assert oldest.timestamp == ~U[2026-03-01 00:00:00.000000Z]
    end

    test "leaves out a change whose block lost consensus" do
      token = insert(:token, ui_multiplier: @four)
      reorged = insert(:block, number: 100, consensus: false)

      insert(:token_ui_multiplier_change,
        token: token,
        block: reorged,
        block_number: 100,
        log_index: 0,
        old_multiplier: @one,
        new_multiplier: @two,
        effective_at: ~U[2026-03-01 00:00:00.000000Z]
      )

      assert UIMultiplierChange.paginated_for_token(token.contract_address_hash) == []
    end

    test "pages with the position of the last row of the previous page" do
      token = insert(:token, ui_multiplier: @four)
      block = insert(:block, number: 100)

      for log_index <- 0..2 do
        insert(:token_ui_multiplier_change,
          token: token,
          block: block,
          block_number: 100,
          log_index: log_index,
          old_multiplier: @one,
          new_multiplier: @two,
          effective_at: ~U[2026-03-01 00:00:00.000000Z]
        )
      end

      assert [%{log_index: 1}, %{log_index: 0}] =
               UIMultiplierChange.paginated_for_token(token.contract_address_hash,
                 paging_options: %PagingOptions{key: {100, 2}, page_size: 10}
               )
    end

    test "keeps a change that is announced but not yet in force" do
      token = insert(:token, ui_multiplier: @one)
      block = insert(:block, number: 100)

      insert(:token_ui_multiplier_change,
        token: token,
        block: block,
        block_number: 100,
        log_index: 0,
        old_multiplier: @one,
        new_multiplier: @two,
        effective_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      )

      assert [%{log_index: 0}] = UIMultiplierChange.paginated_for_token(token.contract_address_hash)
    end
  end

  describe "count_for_token/2" do
    test "counts what paginated_for_token/2 lists" do
      token = insert(:token, ui_multiplier: @four)
      block = insert(:block, number: 100)
      reorged = insert(:block, number: 101, consensus: false)

      for {block, log_index} <- [{block, 0}, {block, 1}, {reorged, 0}] do
        insert(:token_ui_multiplier_change,
          token: token,
          block: block,
          block_number: block.number,
          log_index: log_index,
          old_multiplier: @one,
          new_multiplier: @two,
          effective_at: ~U[2026-03-01 00:00:00.000000Z]
        )
      end

      assert UIMultiplierChange.count_for_token(token.contract_address_hash) == 2
    end

    test "is zero for a token that never announced a change" do
      token = insert(:token)

      assert UIMultiplierChange.count_for_token(token.contract_address_hash) == 0
    end
  end

  defp transfer_at(token, timestamp, block_number) do
    block = insert(:block, number: block_number, timestamp: timestamp)
    transaction = :transaction |> insert() |> with_block(block)

    :token_transfer
    |> insert(
      transaction: transaction,
      block: block,
      block_number: block_number,
      token_contract_address: token.contract_address
    )
    |> Repo.preload([:token, :block])
  end

  defp transaction_at(timestamp, block_number) do
    block = insert(:block, number: block_number, timestamp: timestamp)

    :transaction |> insert() |> with_block(block) |> Repo.preload(:block)
  end
end
