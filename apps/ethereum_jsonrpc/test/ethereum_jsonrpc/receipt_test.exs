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

  # Regression test for https://github.com/blockscout/blockscout/issues/15047
  test "converts a failed EIP-8430 receipt and ignores the fields specific to EIP-8430" do
    transaction_hash = "0xe1c5fe2f599fabab77717e0d0fcaf2ec56bca2df8df325c2d52ef4325d98d7aa"
    block_hash = "0x453ad0ed27870c01e0289e9ece6acf67fad9a0c67b2aa13714f8ccef8c5e3318"

    # The response of `eth_getTransactionReceipt` on an OP Stack test network (chain id 84538453), with an
    # empty `logsBloom` and only the first log.
    receipt =
      Receipt.to_elixir(%{
        "blobGasUsed" => "0x186a0",
        "blockHash" => block_hash,
        "blockNumber" => "0x4ac346",
        "committedPhases" => "0x2",
        "contractAddress" => nil,
        "cumulativeGasUsed" => "0x26d03",
        "daFootprintGasScalar" => "0x190",
        "effectiveGasPrice" => "0x7744d640",
        "from" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
        "gasUsed" => "0x13ce8",
        "l1BaseFeeScalar" => "0x558",
        "l1BlobBaseFee" => "0x1",
        "l1BlobBaseFeeScalar" => "0xc3c9d",
        "l1Fee" => "0xee",
        "l1GasPrice" => "0x7",
        "l1GasUsed" => "0xfa3",
        "logs" => [
          %{
            "address" => "0x81764f32b52cb424c6df38513c7f884fbdb0f99d",
            "blockHash" => block_hash,
            "blockNumber" => "0x4ac346",
            "blockTimestamp" => "0x6af262b5",
            "blockTimestampMs" => "0x1a1c2d19628",
            "data" => "0x00000000000000000000000000000000000000000000000000000000007a3140",
            "logIndex" => "0x0",
            "removed" => false,
            "topics" => [
              "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              "0x000000000000000000000000278161ba9f012b85eeb347bf3326988cfbeb3b7a",
              "0x000000000000000000000000c4bb6341064b99ea7812777be8fd8fa8dfe50c7f"
            ],
            "transactionHash" => transaction_hash,
            "transactionIndex" => "0x2"
          }
        ],
        "logsBloom" => "0x" <> String.duplicate("0", 512),
        "payer" => "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f",
        "phaseStatuses" => ["0x1", "0x1", "0x0"],
        "status" => "0x0",
        "to" => nil,
        "transactionHash" => transaction_hash,
        "transactionIndex" => "0x2",
        "type" => "0x79"
      })

    refute Map.has_key?(receipt, "committedPhases")
    refute Map.has_key?(receipt, "phaseStatuses")
    refute Map.has_key?(receipt, "payer")
    assert [%{"logIndex" => 0, "transactionHash" => ^transaction_hash}] = receipt["logs"]

    assert %{
             created_contract_address_hash: nil,
             cumulative_gas_used: 0x26D03,
             gas_price: 0x7744D640,
             gas_used: 0x13CE8,
             status: :error,
             transaction_hash: ^transaction_hash,
             transaction_index: 2
           } = Receipt.elixir_to_params(receipt)
  end
end
