# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.EdenTest do
  use ExUnit.Case, async: true

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias EthereumJSONRPC.{Blocks, Receipt, Transaction}

  if @chain_type == :eden do
    @sponsored_transaction_hash "0x2b6e28053be6423e05a957b954990cc35971b48eb20d280fea148357fb2d09c0"
    @block_hash "0x33f9bbda3453e26c88733d33db3239bfd03e30b6d6ea338d10b39e246ad0c765"
    @executor_address_hash "0x7d32cfa8ba0daa0d44cf3b0ac372205456fcd0d1"
    @fee_payer_address_hash "0xcfc096e58b1f858e5a3ee88ecaeccb2b464625b5"
    @first_call_to_address_hash "0x11f60a633dd30a8d1a26dd6e20167a9293fb4647"

    defp sponsored_transaction(overrides \\ %{}) do
      Map.merge(
        %{
          "type" => "0x76",
          "chainId" => "0xdeadbfee",
          "nonce" => "0x1",
          "maxPriorityFeePerGas" => "0x0",
          "maxFeePerGas" => "0x7",
          "gasLimit" => "0xa410",
          "calls" => [
            %{
              "to" => @first_call_to_address_hash,
              "value" => "0x0",
              "input" => "0x"
            }
          ],
          "accessList" => [],
          "feePayerSignature" => %{
            "r" => "0xec7d9437f60867299a35037c284879c1597c636a5c96765ea1aed0f015bad70f",
            "s" => "0x2494461cf5efe976f5ad0d1149c12baf64f9d9cf185a9ba09e9c4db3ad255fcf",
            "yParity" => "0x0",
            "v" => "0x0"
          },
          "r" => "0xba19ab4e09b8120319cd794e88474118bd5bb5f5aa1c051d8a72a685824d1d09",
          "s" => "0x6e9f8b863761d9e8066b463af17ce4979ba4b535bd3a09f89e5a4b0227d8e24a",
          "yParity" => "0x0",
          "v" => "0x0",
          "hash" => @sponsored_transaction_hash,
          "blockHash" => @block_hash,
          "blockNumber" => "0xafcd9e4",
          "transactionIndex" => "0x0",
          "from" => @executor_address_hash,
          "gasPrice" => "0x7",
          "blockTimestamp" => "0x6a344506",
          "feePayer" => @fee_payer_address_hash
        },
        overrides
      )
    end

    describe "Transaction.to_elixir/2" do
      test "decodes the Eden 0x76 specific fields" do
        elixir = Transaction.to_elixir(sponsored_transaction())

        assert %{
                 "type" => 118,
                 "gasLimit" => 42_000,
                 "feePayer" => @fee_payer_address_hash,
                 "calls" => [%{"to" => @first_call_to_address_hash, "value" => 0, "input" => "0x"}]
               } = elixir
      end

      test "defaults the omitted call fields" do
        elixir = Transaction.to_elixir(sponsored_transaction(%{"calls" => [%{}]}))

        assert %{"calls" => [%{"to" => nil, "value" => 0, "input" => "0x"}]} = elixir
      end
    end

    describe "Transaction.elixir_to_params/1" do
      test "maps gasLimit, feePayer and calls and derives the compatibility fields" do
        params =
          sponsored_transaction()
          |> Transaction.to_elixir()
          |> Transaction.elixir_to_params()

        assert %{
                 hash: @sponsored_transaction_hash,
                 block_hash: @block_hash,
                 block_number: 184_343_012,
                 index: 0,
                 transaction_index: 0,
                 type: 118,
                 nonce: 1,
                 from_address_hash: @executor_address_hash,
                 fee_payer_address_hash: @fee_payer_address_hash,
                 gas: 42_000,
                 gas_price: 7,
                 max_fee_per_gas: 7,
                 max_priority_fee_per_gas: 0,
                 to_address_hash: @first_call_to_address_hash,
                 input: "0x",
                 value: 0,
                 calls: [%{"to" => @first_call_to_address_hash, "value" => 0, "input" => "0x"}]
               } = params
      end

      test "derives `to`, `input` and `value` from the first call and sums the values of all calls" do
        second_call_to_address_hash = "0x0000000000000000000000000000000000000001"

        params =
          %{
            "calls" => [
              %{"to" => @first_call_to_address_hash, "value" => "0x1", "input" => "0xdeadbeef"},
              %{"to" => second_call_to_address_hash, "value" => "0x2", "input" => "0xc0ffee"}
            ]
          }
          |> sponsored_transaction()
          |> Transaction.to_elixir()
          |> Transaction.elixir_to_params()

        assert %{
                 to_address_hash: @first_call_to_address_hash,
                 input: "0xdeadbeef",
                 value: 3,
                 calls: [
                   %{"to" => @first_call_to_address_hash, "value" => 1, "input" => "0xdeadbeef"},
                   %{"to" => ^second_call_to_address_hash, "value" => 2, "input" => "0xc0ffee"}
                 ]
               } = params
      end

      test "handles an empty calls array with the defaults compatible with the transaction validation" do
        params =
          %{"calls" => []}
          |> sponsored_transaction()
          |> Transaction.to_elixir()
          |> Transaction.elixir_to_params()

        assert %{to_address_hash: nil, input: "0x", value: 0, gas: 42_000, calls: []} = params
      end

      test "keeps the regular transactions untouched" do
        params =
          %{
            "type" => "0x2",
            "gas" => "0x5208",
            "to" => @first_call_to_address_hash,
            "input" => "0x",
            "value" => "0x1"
          }
          |> sponsored_transaction()
          |> Map.drop(["gasLimit", "calls", "feePayer"])
          |> Transaction.to_elixir()
          |> Transaction.elixir_to_params()

        assert %{type: 2, gas: 21_000, to_address_hash: @first_call_to_address_hash, input: "0x", value: 1} = params
        refute Map.has_key?(params, :fee_payer_address_hash)
        refute Map.has_key?(params, :calls)
      end
    end

    describe "Receipt.elixir_to_params/1" do
      test "keeps the receipt of a sponsored transaction intact" do
        params =
          %{
            "status" => "0x1",
            "cumulativeGasUsed" => "0x5208",
            "gasUsed" => "0x5208",
            "type" => "0x76",
            "transactionHash" => @sponsored_transaction_hash,
            "transactionIndex" => "0x0",
            "blockHash" => @block_hash,
            "blockNumber" => "0xafcd9e4",
            "contractAddress" => nil,
            "effectiveGasPrice" => "0x7",
            "feePayer" => @fee_payer_address_hash
          }
          |> Receipt.to_elixir()
          |> Receipt.elixir_to_params()

        assert %{
                 status: :ok,
                 gas_used: 21_000,
                 cumulative_gas_used: 21_000,
                 gas_price: 7,
                 created_contract_address_hash: nil,
                 transaction_hash: @sponsored_transaction_hash,
                 transaction_index: 0
               } = params
      end
    end

    describe "Blocks.from_responses/2" do
      test "imports a block containing an Eden 0x76 transaction" do
        responses = [
          %{
            id: 0,
            result: %{
              "difficulty" => "0x0",
              "extraData" => "0x",
              "gasLimit" => "0x1c9c38000",
              "gasUsed" => "0x5208",
              "hash" => @block_hash,
              "logsBloom" => "0x00",
              "miner" => "0x2be4490805be0d0500b38a6687d94738a26ffc22",
              "number" => "0xafcd9e4",
              "parentHash" => "0xaadffcba9d17d99d20c7a0ec73bd75b7b1a0b77b61c5639ed86c042dfce27da0",
              "receiptsRoot" => "0xc56351659e0e5f72832359105b5ab38d5c6c20602262943c45a48b540ff539b1",
              "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
              "size" => "0x31c",
              "stateRoot" => "0x773da6b24a970cd5ba7cdae67d2e5b8420edd7cff1d6969b798e845e840e883b",
              "timestamp" => "0x6a344506",
              "totalDifficulty" => "0x0",
              "transactions" => [sponsored_transaction()],
              "transactionsRoot" => "0x5c9b227047181f8d167dbdc9310a326c066d651dc2296696e8f7d561cae406d9",
              "uncles" => []
            }
          }
        ]

        assert %Blocks{errors: [], transactions_params: [transaction_params]} =
                 Blocks.from_responses(responses, %{0 => %{number: 184_343_012}})

        assert %{
                 hash: @sponsored_transaction_hash,
                 block_hash: @block_hash,
                 type: 118,
                 gas: 42_000,
                 to_address_hash: @first_call_to_address_hash,
                 fee_payer_address_hash: @fee_payer_address_hash,
                 calls: [%{"to" => @first_call_to_address_hash, "value" => 0, "input" => "0x"}]
               } = transaction_params
      end
    end
  end
end
