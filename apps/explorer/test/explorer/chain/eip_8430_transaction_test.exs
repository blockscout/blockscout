# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.EIP8430TransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.EIP8430Transaction

  describe "transaction_hashes_to_nonce_keys/1" do
    test "returns an empty map for an empty list" do
      insert(:eip_8430_transaction, nonce_key: 5)

      assert EIP8430Transaction.transaction_hashes_to_nonce_keys([]) == %{}
    end

    test "returns the `nonce_key` of each given transaction" do
      nonce_free_nonce_key = Decimal.new(Bitwise.bsl(1, 256) - 1)

      %{transaction_hash: standard_hash} = insert(:eip_8430_transaction, nonce_key: 0)
      %{transaction_hash: channel_hash} = insert(:eip_8430_transaction, nonce_key: 5)
      %{transaction_hash: nonce_free_hash} = insert(:eip_8430_transaction, nonce_key: nonce_free_nonce_key)

      nonce_keys =
        EIP8430Transaction.transaction_hashes_to_nonce_keys([standard_hash, channel_hash, nonce_free_hash])

      assert nonce_keys |> Map.keys() |> Enum.sort() == Enum.sort([standard_hash, channel_hash, nonce_free_hash])
      assert Decimal.eq?(nonce_keys[standard_hash], 0)
      assert Decimal.eq?(nonce_keys[channel_hash], 5)
      assert Decimal.eq?(nonce_keys[nonce_free_hash], nonce_free_nonce_key)
    end

    test "does not return the rows of other transactions" do
      %{transaction_hash: requested_hash} = insert(:eip_8430_transaction, nonce_key: 5)
      insert(:eip_8430_transaction, nonce_key: 6)

      assert requested_hash |> List.wrap() |> EIP8430Transaction.transaction_hashes_to_nonce_keys() |> Map.keys() ==
               [requested_hash]
    end

    test "has no entry for a transaction without a row" do
      transaction = insert(:transaction, type: 0x79)

      assert EIP8430Transaction.transaction_hashes_to_nonce_keys([transaction.hash]) == %{}
    end
  end
end
