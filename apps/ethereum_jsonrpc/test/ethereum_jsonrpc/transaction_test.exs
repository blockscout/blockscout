# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.TransactionTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Transaction

  alias EthereumJSONRPC.Transaction

  describe "to_elixir/1" do
    test "skips unsupported keys" do
      map = %{"key" => "value", "key1" => "value1"}

      assert %{ignore: :ignore} = Transaction.to_elixir(map)
    end
  end

  describe "elixir_to_params/1" do
    test "supports minimal OP Stack PostExec transactions" do
      assert Transaction.elixir_to_params(%{
               "blockHash" => "0xab6dfcf5ad132602e939db5f84f56945b1be4e136daab002f9bf9ff0c7f9f7a5",
               "blockNumber" => 27,
               "gas" => 0,
               "hash" => "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
               "input" => "0xc3011b80",
               "transactionIndex" => 17,
               "type" => 0x7D,
               "value" => 0
             }) == %{
               block_hash: "0xab6dfcf5ad132602e939db5f84f56945b1be4e136daab002f9bf9ff0c7f9f7a5",
               block_number: 27,
               from_address_hash: "0x0000000000000000000000000000000000000000",
               gas: 0,
               gas_price: 0,
               hash: "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
               index: 17,
               input: "0xc3011b80",
               nonce: 0,
               r: 0,
               s: 0,
               to_address_hash: nil,
               transaction_index: 17,
               type: 0x7D,
               v: 0,
               value: 0
             }
    end
  end
end
