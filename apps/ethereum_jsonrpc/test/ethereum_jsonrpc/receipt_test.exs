# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.ReceiptTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipt

  doctest Receipt

  describe "to_elixir/1" do
    test "ignores new key" do
      assert Receipt.to_elixir(%{
               "new_key" => "new_value",
               "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
             }) == %{
               "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
             }
    end

    # Regression test for https://github.com/poanetwork/blockscout/issues/638
    test ~s|"status" => nil is treated the same as no status| do
      assert Receipt.to_elixir(%{"status" => nil, "transactionHash" => "0x0"}) == %{"transactionHash" => "0x0"}
    end
  end

  test "leaves nil if blockNumber is nil" do
    assert Receipt.to_elixir(%{"blockNumber" => nil, "transactionHash" => "0x0"}) == %{
             "transactionHash" => "0x0",
             "blockNumber" => nil
           }
  end

  test "converts an OP Stack PostExec receipt into collated transaction fields" do
    receipt =
      Receipt.to_elixir(%{
        "blockHash" => "0xab6dfcf5ad132602e939db5f84f56945b1be4e136daab002f9bf9ff0c7f9f7a5",
        "blockNumber" => "0x1b",
        "contractAddress" => nil,
        "cumulativeGasUsed" => "0x5208",
        "effectiveGasPrice" => "0x0",
        "gasUsed" => "0x0",
        "logs" => [],
        "logsBloom" => "0x" <> String.duplicate("0", 512),
        "status" => "0x1",
        "transactionHash" => "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
        "transactionIndex" => "0x11",
        "type" => "0x7d"
      })

    assert %{
             cumulative_gas_used: 21_000,
             gas_used: 0,
             status: :ok,
             transaction_hash: "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
             transaction_index: 17
           } = Receipt.elixir_to_params(receipt)
  end
end
