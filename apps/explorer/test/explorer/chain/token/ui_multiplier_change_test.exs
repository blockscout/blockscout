# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.UIMultiplierChangeTest do
  use Explorer.DataCase

  alias Explorer.Chain.Token.UIMultiplierChange

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
end
