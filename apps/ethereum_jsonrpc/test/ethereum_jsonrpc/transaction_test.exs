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
    test "adds compatibility defaults to minimal PostExec transactions only on OP Stack chains" do
      transaction = %{
        "blockHash" => "0xab6dfcf5ad132602e939db5f84f56945b1be4e136daab002f9bf9ff0c7f9f7a5",
        "blockNumber" => 27,
        "gas" => 0,
        "hash" => "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
        "input" => "0xc3011b80",
        "transactionIndex" => 17,
        "type" => 0x7D,
        "value" => 0
      }

      if Application.get_env(:explorer, :chain_type) == :optimism do
        assert Transaction.elixir_to_params(transaction) == %{
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
      else
        assert_raise FunctionClauseError, fn -> Transaction.elixir_to_params(transaction) end
      end
    end

    test "preserves standard fields for type 0x7D transactions" do
      authorization_list = [%{"address" => "0x0000000000000000000000000000000000000001", "nonce" => 1}]

      assert %{
               created_contract_address_hash: "0x0000000000000000000000000000000000000002",
               from_address_hash: "0x0000000000000000000000000000000000000003",
               max_fee_per_gas: 30,
               max_priority_fee_per_gas: 2,
               authorization_list: ^authorization_list,
               type: 0x7D
             } =
               Transaction.elixir_to_params(%{
                 "authorizationList" => authorization_list,
                 "blockHash" => "0xab6dfcf5ad132602e939db5f84f56945b1be4e136daab002f9bf9ff0c7f9f7a5",
                 "blockNumber" => 27,
                 "creates" => "0x0000000000000000000000000000000000000002",
                 "from" => "0x0000000000000000000000000000000000000003",
                 "gas" => 21_000,
                 "gasPrice" => 10,
                 "hash" => "0x39ee8fea8d4e719a75a5d64a4d5e34bdbd62f2543c88d00d0f00f91c8f1d8a20",
                 "input" => "0x",
                 "maxFeePerGas" => 30,
                 "maxPriorityFeePerGas" => 2,
                 "nonce" => 1,
                 "transactionIndex" => 17,
                 "type" => 0x7D,
                 "value" => 1
               })
    end

    # Regression test for https://github.com/blockscout/blockscout/issues/15047
    test "adds zero signature values to EIP-8430 transactions for all chain types" do
      # The response of `eth_getTransactionByHash` on an OP Stack test network (chain id 84538453).
      transaction = %{
        "accountChanges" => [],
        "blockHash" => "0x07ff03eccab958e2e1312ec4d889b0690d7ae3ff0b5028a04926a54b91f66540",
        "blockNumber" => "0x4a9b69",
        "blockTimestamp" => "0x6af25abc",
        "blockTimestampMs" => "0x1a1c2b27180",
        "calls" => [
          [%{"data" => "0x", "to" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a", "value" => "0x0"}]
        ],
        "chainId" => "0x509f455",
        "from" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
        "gas" => "0x1255c",
        "gasPrice" => "0x7744d640",
        "hash" => "0x3e9e6f89469aca60687eaab43e0a2436e5c23acbe3ccd9dd0342fa6004d99b1c",
        "input" => "0x",
        "maxFeePerGas" => "0x77541880",
        "maxPriorityFeePerGas" => "0x3baa0c40",
        "metadata" => "0x53706f6e736f726564207472616e73616374696f6e",
        "nonce" => "0x0",
        "nonceKey" => "0x0",
        "payer" => "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f",
        "payerAuth" =>
          "0x0000000000000000000000000000000000000001c1a1dc1e515204f16a2d6c18b8f9caacab7c1d49c27b73c1c1786b2f23500a3c0409bd58182d6efbd9a48ebfceadd469dc03f80bd708eca95d539c92082571da1c",
        "sender" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
        "senderAuth" =>
          "0x0000000000000000000000000000000000000001f4646b5a9fcff6e29768f4d61a65b4479946e37a094a3116f5b76486ce466abf1a514af6b3ed852c8b30fcc82fb76a3e8bb6f9c92c2a77e7055c42bdbb8bdccc1b",
        "to" => nil,
        "transactionIndex" => "0x2",
        "type" => "0x79",
        "validAfter" => "0x0",
        "validBefore" => "0x1a1c2b2a0b1",
        "value" => "0x0"
      }

      assert transaction |> Transaction.to_elixir() |> Transaction.elixir_to_params() == %{
               block_hash: "0x07ff03eccab958e2e1312ec4d889b0690d7ae3ff0b5028a04926a54b91f66540",
               block_number: 0x4A9B69,
               from_address_hash: "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
               gas: 0x1255C,
               gas_price: 0x7744D640,
               hash: "0x3e9e6f89469aca60687eaab43e0a2436e5c23acbe3ccd9dd0342fa6004d99b1c",
               index: 2,
               input: "0x",
               max_fee_per_gas: 0x77541880,
               max_priority_fee_per_gas: 0x3BAA0C40,
               nonce: 0,
               r: 0,
               s: 0,
               to_address_hash: nil,
               transaction_index: 2,
               type: 0x79,
               v: 0,
               value: 0,
               eip_8430_fields: %{
                 sender: "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
                 nonce_key: 0,
                 valid_after: 0,
                 valid_before: 0x1A1C2B2A0B1,
                 metadata: "0x53706f6e736f726564207472616e73616374696f6e",
                 payer: "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f",
                 sender_auth:
                   "0x0000000000000000000000000000000000000001f4646b5a9fcff6e29768f4d61a65b4479946e37a094a3116f5b76486ce466abf1a514af6b3ed852c8b30fcc82fb76a3e8bb6f9c92c2a77e7055c42bdbb8bdccc1b",
                 payer_auth:
                   "0x0000000000000000000000000000000000000001c1a1dc1e515204f16a2d6c18b8f9caacab7c1d49c27b73c1c1786b2f23500a3c0409bd58182d6efbd9a48ebfceadd469dc03f80bd708eca95d539c92082571da1c",
                 account_changes: []
               }
             }
    end

    test "preserves present signature values of EIP-8430 transactions" do
      assert %{r: 11, s: 12, v: 1, type: 0x79} =
               Transaction.elixir_to_params(%{
                 "blockHash" => "0x07ff03eccab958e2e1312ec4d889b0690d7ae3ff0b5028a04926a54b91f66540",
                 "blockNumber" => 0x4A9B69,
                 "from" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
                 "gas" => 0x1255C,
                 "gasPrice" => 0x7744D640,
                 "hash" => "0x3e9e6f89469aca60687eaab43e0a2436e5c23acbe3ccd9dd0342fa6004d99b1c",
                 "input" => "0x",
                 "maxFeePerGas" => 0x77541880,
                 "maxPriorityFeePerGas" => 0x3BAA0C40,
                 "nonce" => 0,
                 "r" => 11,
                 "s" => 12,
                 "to" => nil,
                 "transactionIndex" => 2,
                 "type" => 0x79,
                 "v" => 1,
                 "value" => 0
               })
    end

    test "accepts an EIP-8430 transaction without sender and payer" do
      transaction = Map.drop(eip_8430_transaction(), ["sender", "payer"])

      assert %{eip_8430_fields: %{sender: nil, payer: nil}} =
               transaction |> Transaction.to_elixir() |> Transaction.elixir_to_params()
    end

    test "accepts an EIP-8430 transaction with null sender and payer" do
      transaction = Map.merge(eip_8430_transaction(), %{"sender" => nil, "payer" => nil})

      assert %{eip_8430_fields: %{sender: nil, payer: nil}} =
               transaction |> Transaction.to_elixir() |> Transaction.elixir_to_params()
    end

    test "passes sender and payer of an EIP-8430 transaction without interpretation" do
      transaction = Map.merge(eip_8430_transaction(), %{"sender" => "0x", "payer" => "0x00"})

      assert %{eip_8430_fields: %{sender: "0x", payer: "0x00"}} =
               transaction |> Transaction.to_elixir() |> Transaction.elixir_to_params()
    end

    test "converts the maximum nonce key of an EIP-8430 transaction" do
      transaction =
        Map.put(
          eip_8430_transaction(),
          "nonceKey",
          "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        )

      assert %{eip_8430_fields: %{nonce_key: nonce_key}} =
               transaction |> Transaction.to_elixir() |> Transaction.elixir_to_params()

      assert nonce_key == Bitwise.bsl(1, 256) - 1
    end

    test "raises on a malformed nonce key of an EIP-8430 transaction" do
      transaction = Map.put(eip_8430_transaction(), "nonceKey", "0x")

      assert_raise ArgumentError, fn -> Transaction.to_elixir(transaction) end
    end

    test "does not add EIP-8430 fields to transactions of other types" do
      transaction = Map.put(eip_8430_transaction(), "type", "0x2")

      refute transaction
             |> Transaction.to_elixir()
             |> Transaction.elixir_to_params()
             |> Map.has_key?(:eip_8430_fields)
    end
  end

  # A reduced `eth_getTransactionByHash` response for an EIP-8430 transaction.
  defp eip_8430_transaction do
    %{
      "accountChanges" => [],
      "blockHash" => "0x07ff03eccab958e2e1312ec4d889b0690d7ae3ff0b5028a04926a54b91f66540",
      "blockNumber" => "0x4a9b69",
      "from" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
      "gas" => "0x1255c",
      "gasPrice" => "0x7744d640",
      "hash" => "0x3e9e6f89469aca60687eaab43e0a2436e5c23acbe3ccd9dd0342fa6004d99b1c",
      "input" => "0x",
      "maxFeePerGas" => "0x77541880",
      "maxPriorityFeePerGas" => "0x3baa0c40",
      "metadata" => "0x",
      "nonce" => "0x0",
      "nonceKey" => "0x0",
      "payer" => "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f",
      "payerAuth" => "0x",
      "sender" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
      "senderAuth" => "0x01",
      "to" => nil,
      "transactionIndex" => "0x2",
      "type" => "0x79",
      "validAfter" => "0x0",
      "validBefore" => "0x0",
      "value" => "0x0"
    }
  end
end
