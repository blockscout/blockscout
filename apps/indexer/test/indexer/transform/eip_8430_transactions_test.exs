# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.EIP8430TransactionsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias EthereumJSONRPC.{Receipt, Transaction}
  alias Indexer.Block.Fetcher.Receipts
  alias Indexer.Transform.EIP8430Transactions

  @transaction_hash "0xfe60000e5777f8e22da2f002ba1984d869cbac9716f273e50fd11d7e38da3c52"
  @sender "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a"
  @payer "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f"
  @zero_address "0x0000000000000000000000000000000000000000"

  # The response of `eth_getTransactionByHash` on an OP Stack test network (chain id 84538453),
  # with a reduced `calls` list.
  @raw_transaction %{
    "accountChanges" => [],
    "blockHash" => "0x31495dba691daccc5dbcd33acf8941a942ff7d9981c5ec18dc275b8fd43c8494",
    "blockNumber" => "0x4abe4d",
    "blockTimestamp" => "0x6af261b7",
    "blockTimestampMs" => "0x1a1c2cdb3a0",
    "calls" => [
      [%{"data" => "0x", "to" => "0x4624412ed6f2f1229d61ca65721dceb081e56660", "value" => "0x64f43391f000"}]
    ],
    "chainId" => "0x509f455",
    "from" => @sender,
    "gas" => "0x2f634",
    "gasPrice" => "0x7744d640",
    "hash" => @transaction_hash,
    "input" => "0x",
    "maxFeePerGas" => "0x77541880",
    "maxPriorityFeePerGas" => "0x3baa0c40",
    "metadata" => "0x35306d65206d65374064403740",
    "nonce" => "0x0",
    "nonceKey" => "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    "payer" => @payer,
    "payerAuth" =>
      "0x0000000000000000000000000000000000000001a17c530664cf577bbed458aa2cd4fedf9a3538ccdc21342c30947530a977833f499e131412d94d23125009b32a9fb98975f8b5b5c8a6f68543d37f782bf779791b",
    "sender" => @sender,
    "senderAuth" =>
      "0x00000000000000000000000000000000000000012f1cc92ef873d4f39ce758efc3d5ca8b13234199ce956213cc4c05790a4c67c31c06e5558513b9857e63af43326ceadeec08be2c3d61e4c753345759ea0f6f3b1b",
    "to" => nil,
    "transactionIndex" => "0x2",
    "type" => "0x79",
    "validAfter" => "0x0",
    "validBefore" => "0x1a1c2cde40d",
    "value" => "0x0"
  }

  # The response of `eth_getTransactionReceipt` for the same transaction, with an empty
  # `logsBloom` and without logs. The transaction on the network has two call phases.
  @raw_receipt %{
    "blobGasUsed" => "0x18e70",
    "blockHash" => "0x31495dba691daccc5dbcd33acf8941a942ff7d9981c5ec18dc275b8fd43c8494",
    "blockNumber" => "0x4abe4d",
    "committedPhases" => "0x2",
    "contractAddress" => nil,
    "cumulativeGasUsed" => "0x3a5ca",
    "daFootprintGasScalar" => "0x190",
    "effectiveGasPrice" => "0x7744d640",
    "from" => @sender,
    "gasUsed" => "0x232ef",
    "l1BaseFeeScalar" => "0x558",
    "l1BlobBaseFee" => "0x1",
    "l1BlobBaseFeeScalar" => "0xc3c9d",
    "l1Fee" => "0xf3",
    "l1GasPrice" => "0x7",
    "l1GasUsed" => "0xff3",
    "logs" => [],
    "logsBloom" => "0x" <> String.duplicate("0", 512),
    "metadata" => "0x35306d65206d65374064403740",
    "payer" => @payer,
    "phaseStatuses" => ["0x1", "0x1"],
    "status" => "0x1",
    "to" => nil,
    "transactionHash" => @transaction_hash,
    "transactionIndex" => "0x2",
    "type" => "0x79"
  }

  describe "parse/1" do
    test "builds the row from a raw transaction and a raw receipt of the node" do
      assert [@raw_transaction] |> to_params() |> EIP8430Transactions.parse() == [
               %{
                 transaction_hash: @transaction_hash,
                 has_named_sender: true,
                 nonce_key: Bitwise.bsl(1, 256) - 1,
                 valid_after: 0,
                 valid_before: 0x1A1C2CDE40D,
                 metadata: "0x35306d65206d65374064403740",
                 payer_type: :named,
                 payer: @payer,
                 sender_auth: @raw_transaction["senderAuth"],
                 payer_auth: @raw_transaction["payerAuth"],
                 account_changes: [],
                 resolved_payer_address_hash: @payer,
                 committed_phases_count: 2
               }
             ]
    end

    test "returns no rows for transactions of other types" do
      transaction = Map.put(@raw_transaction, "type", "0x2")

      assert [transaction] |> to_params() |> EIP8430Transactions.parse() == []
      assert EIP8430Transactions.parse([]) == []
    end

    test "sets the named sender flag for a 20-byte address" do
      assert [%{has_named_sender: true}] = parse_with(%{"sender" => @sender})
    end

    test "clears the named sender flag for an empty sender without a warning" do
      log =
        capture_log(fn ->
          assert [%{has_named_sender: false}] = parse_without("sender")
          assert [%{has_named_sender: false}] = parse_with(%{"sender" => nil})
          assert [%{has_named_sender: false}] = parse_with(%{"sender" => "0x"})
        end)

      refute log =~ "Unexpected sender value"
    end

    test "clears the named sender flag for an unexpected sender and writes a warning" do
      # The list includes a string of 20 characters with and without the `0x` prefix, and a
      # string of the address length that is not hexadecimal.
      for sender <- [
            "0x0102",
            "garbage",
            5,
            "0x123456789012345678",
            "abcdefghijklmnopqrst",
            "0xzz8161ba9f012b85eeb347bf3326988cfbeb3b7a"
          ] do
        log =
          capture_log(fn ->
            assert [%{has_named_sender: false, transaction_hash: @transaction_hash}] =
                     parse_with(%{"sender" => sender})
          end)

        assert log =~ "Unexpected sender value"
        assert log =~ @transaction_hash
      end
    end

    test "classifies an absent payer as self-pay and keeps the form of the node" do
      log =
        capture_log(fn ->
          assert [%{payer_type: :self, payer: nil}] = parse_without("payer")
          assert [%{payer_type: :self, payer: nil}] = parse_with(%{"payer" => nil})
          assert [%{payer_type: :self, payer: "0x"}] = parse_with(%{"payer" => "0x"})
        end)

      refute log =~ "Unexpected payer value"
    end

    test "classifies the single zero byte as an open payer" do
      assert [%{payer_type: :open, payer: "0x00"}] = parse_with(%{"payer" => "0x00"})
    end

    test "takes the resolved payer of an open payer transaction from the receipt" do
      assert [%{payer_type: :open, payer: "0x00", resolved_payer_address_hash: @payer}] =
               parse_with(%{"payer" => "0x00"}, %{"payer" => @payer})
    end

    test "takes the resolved payer of a self-pay transaction from the receipt" do
      assert [%{payer_type: :self, payer: nil, resolved_payer_address_hash: @sender}] =
               parse_with(%{"payer" => nil}, %{"payer" => @sender})
    end

    test "keeps the number of committed phases of a failed transaction" do
      assert [%{committed_phases_count: 0}] = parse_with(%{}, %{"committedPhases" => "0x0", "status" => "0x0"})
    end

    test "does not interpret the resolved payer and writes no warning" do
      log =
        capture_log(fn ->
          assert [%{resolved_payer_address_hash: @zero_address}] = parse_with(%{}, %{"payer" => @zero_address})
          assert [%{resolved_payer_address_hash: "garbage"}] = parse_with(%{}, %{"payer" => "garbage"})
        end)

      assert log == ""
    end

    test "leaves the receipt values empty if the node returns a receipt without them" do
      assert [%{resolved_payer_address_hash: nil, committed_phases_count: nil}] =
               parse_with(%{}, %{"payer" => nil, "committedPhases" => nil})
    end

    test "leaves the receipt values empty for a transaction without the receipt fields" do
      transactions = Enum.map(to_params([@raw_transaction]), &Map.delete(&1, :eip_8430_receipt_fields))

      assert [%{resolved_payer_address_hash: nil, committed_phases_count: nil, payer_type: :named}] =
               EIP8430Transactions.parse(transactions)
    end

    test "classifies a payer address as a named payer" do
      assert [%{payer_type: :named, payer: @payer}] = parse_with(%{"payer" => @payer})
      assert [%{payer_type: :named, payer: @sender}] = parse_with(%{"payer" => @sender})
    end

    test "classifies a payer of an unexpected length as unknown and keeps the bytes" do
      log =
        capture_log(fn ->
          assert [%{payer_type: :unknown, payer: "0x0102"}] = parse_with(%{"payer" => "0x0102"})
        end)

      assert log =~ "Unexpected payer value"
      assert log =~ @transaction_hash
    end

    test "classifies a hex string of 20 characters as an unknown payer and keeps the bytes" do
      payer = "0x123456789012345678"

      log =
        capture_log(fn ->
          assert [%{payer_type: :unknown, payer: ^payer}] = parse_with(%{"payer" => payer})
        end)

      assert log =~ "Unexpected payer value"
    end

    test "classifies the zero address as an unknown payer and keeps the bytes" do
      log =
        capture_log(fn ->
          assert [%{payer_type: :unknown, payer: @zero_address}] = parse_with(%{"payer" => @zero_address})
        end)

      assert log =~ "Unexpected payer value"
    end

    test "classifies a payer that is not a hex string of bytes as unknown and drops the value" do
      for payer <- ["garbage", "0xzz", 5, "abcdefghijklmnopqrst", "0xzz8161ba9f012b85eeb347bf3326988cfbeb3b7a"] do
        log =
          capture_log(fn ->
            assert [%{payer_type: :unknown, payer: nil}] = parse_with(%{"payer" => payer})
          end)

        assert log =~ "Unexpected payer value"
      end
    end

    test "keeps account changes with entries of different forms" do
      account_changes = [
        %{"type" => "0x1", "target" => "0x0000000000000000000000000000000000000001"},
        "0xd60194000000000000000000000000000000000000000001"
      ]

      assert [%{account_changes: ^account_changes}] = parse_with(%{"accountChanges" => account_changes})
    end
  end

  defp parse_with(overrides, receipt_overrides \\ %{}) do
    [Map.merge(@raw_transaction, overrides)] |> to_params(receipt_overrides) |> EIP8430Transactions.parse()
  end

  defp parse_without(key) do
    [Map.delete(@raw_transaction, key)] |> to_params() |> EIP8430Transactions.parse()
  end

  # Converts raw transactions of the node and their receipts in the same way as the block
  # fetcher does. Each transaction gets the raw receipt with its own hash and type.
  # `Receipts.put/2` merges the two maps, so the test fails if the nested key of the receipt
  # replaces the nested key of the transaction.
  defp to_params(raw_transactions, receipt_overrides \\ %{}) do
    transactions_params =
      Enum.map(raw_transactions, &(&1 |> Transaction.to_elixir() |> Transaction.elixir_to_params()))

    receipts_params =
      Enum.map(raw_transactions, fn raw_transaction ->
        @raw_receipt
        |> Map.merge(%{"transactionHash" => raw_transaction["hash"], "type" => raw_transaction["type"]})
        |> Map.merge(receipt_overrides)
        |> Receipt.to_elixir()
        |> Receipt.elixir_to_params()
      end)

    Receipts.put(transactions_params, receipts_params)
  end
end
