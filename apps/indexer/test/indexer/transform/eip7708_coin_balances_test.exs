# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.EIP7708CoinBalancesTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.TokenTransfer
  alias Indexer.Transform.{AddressCoinBalances, Addresses}

  @from "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @to "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  @burn_topic "0x" <> String.duplicate("0", 64)

  test "queues both participants and imports them as addresses without internal transactions" do
    params = AddressCoinBalances.params_set(%{logs_params: [transfer_log()]})

    assert params ==
             MapSet.new([
               %{address_hash: @from, block_number: 100},
               %{address_hash: @to, block_number: 100}
             ])

    addresses = Addresses.extract_addresses(%{coin_balance_candidates: params})

    assert MapSet.new(addresses, &{&1.hash, &1.fetched_coin_balance_block_number}) ==
             MapSet.new([{@from, 100}, {@to, 100}])
  end

  test "handles mixed-case emitters and skips the burn address" do
    "0x" <> emitter = TokenTransfer.eip7708_system_address()
    log = %{transfer_log() | address_hash: "0x" <> String.upcase(emitter), third_topic: @burn_topic}

    assert AddressCoinBalances.params_set(%{logs_params: [log]}) ==
             MapSet.new([%{address_hash: @from, block_number: 100}])
  end

  test "ignores regular token transfers and pending system logs" do
    token_log = %{transfer_log() | address_hash: @to}
    pending_log = Map.put(transfer_log(), :type, "pending")

    assert AddressCoinBalances.params_set(%{logs_params: [token_log, pending_log]}) == MapSet.new()
  end

  test "deduplicates entries also discovered by internal transaction tracing" do
    internal_transaction = %{
      block_number: 100,
      type: "call",
      call_type: "call",
      value: 1,
      from_address_hash: @from,
      to_address_hash: @to
    }

    params =
      AddressCoinBalances.params_set(%{
        internal_transactions_params: [internal_transaction],
        logs_params: [transfer_log()]
      })

    assert MapSet.size(params) == 2
  end

  defp transfer_log do
    %{
      address_hash: TokenTransfer.eip7708_system_address(),
      first_topic: TokenTransfer.constant(),
      second_topic: topic(@from),
      third_topic: topic(@to),
      block_number: 100
    }
  end

  defp topic("0x" <> address), do: "0x000000000000000000000000" <> address
end
