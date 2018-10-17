defmodule Explorer.Counters.TokenHoldersCounterTest do
  use Explorer.DataCase

  alias Explorer.Chain.Token
  alias Explorer.Counters.TokenHoldersCounter

  describe "consolidate/0" do
    test "consolidates the token holders info with the most current database info" do
      address_a = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")
      address_b = insert(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address_a,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      TokenHoldersCounter.consolidate()

      assert TokenHoldersCounter.fetch(contract_address_hash) == 1

      insert(
        :token_balance,
        address: address_b,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      TokenHoldersCounter.consolidate()

      assert TokenHoldersCounter.fetch(contract_address_hash) == 2
    end
  end

  describe "fetch/1" do
    test "fetchs the total token holders by token contract address hash" do
      token = insert(:token)

      assert TokenHoldersCounter.fetch(token.contract_address_hash) == 0

      TokenHoldersCounter.insert_counter({token.contract_address_hash.bytes, 15})

      assert TokenHoldersCounter.fetch(token.contract_address_hash) == 15
    end
  end
end
