defmodule EthereumJSONRPC.ReceiptsTest do
  use ExUnit.Case, async: true
  use EthereumJSONRPC.Case

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias EthereumJSONRPC.Receipts

  setup :verify_on_exit!

  doctest Receipts

  describe "fetch/2" do
    test "with receipts and logs", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{
        created_contract_address_hash: nil,
        cumulative_gas_used: cumulative_gas_used,
        gas_used: gas_used,
        address_hash: address_hash,
        block_number: block_number,
        data: data,
        index: index,
        first_topic: first_topic,
        status: status,
        type: type,
        transaction_hash: transaction_hash,
        transaction_index: transaction_index
      } =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Geth ->
            %{
              created_contract_address_hash: nil,
              cumulative_gas_used: 884_322,
              address_hash: "0x1e2fbe6be9eb39fc894d38be976111f332172d83",
              block_number: 3_560_000,
              block_hash: nil,
              data:
                "0x00000000000000000000000033066f6a8adf2d4f5db193524b6fbae062ec0d110000000000000000000000000000000000000000000000000000000000001030",
              index: 12,
              first_topic: "0xf6db2bace4ac8277384553ad9603d045220a91fb2448ab6130d7a6f044f9a8cf",
              gas_used: 106_025,
              status: nil,
              type: nil,
              transaction_hash: "0xd3efddbbeb6ad8d8bb3f6b8c8fb6165567e9dd868013146bdbeb60953c82822a",
              transaction_index: 17
            }

          EthereumJSONRPC.Parity ->
            %{
              created_contract_address_hash: nil,
              block_hash: nil,
              cumulative_gas_used: 50450,
              gas_used: 50450,
              address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: 37,
              data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
              index: 0,
              first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
              status: :ok,
              type: "mined",
              transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
              transaction_index: 0
            }
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        native_status =
          case status do
            :ok -> "0x1"
            :error -> "0x0"
            nil -> nil
          end

        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => integer_to_quantity(cumulative_gas_used),
                 "gasUsed" => integer_to_quantity(gas_used),
                 "logs" => [
                   %{
                     "address" => address_hash,
                     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "blockNumber" => integer_to_quantity(block_number),
                     "blockHash" => nil,
                     "data" => data,
                     "logIndex" => integer_to_quantity(index),
                     "topics" => [first_topic],
                     "transactionHash" => transaction_hash,
                     "type" => type
                   }
                 ],
                 "status" => native_status,
                 "transactionHash" => transaction_hash,
                 "transactionIndex" => integer_to_quantity(transaction_index)
               }
             }
           ]}
        end)
      end

      assert {:ok,
              %{
                logs: [
                  %{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    data: ^data,
                    first_topic: ^first_topic,
                    fourth_topic: nil,
                    index: ^index,
                    second_topic: nil,
                    third_topic: nil,
                    transaction_hash: ^transaction_hash
                  }
                  | _
                ],
                receipts: [
                  %{
                    cumulative_gas_used: ^cumulative_gas_used,
                    gas_used: ^gas_used,
                    status: ^status,
                    transaction_hash: ^transaction_hash,
                    transaction_index: ^transaction_index
                  }
                ]
              }} =
               Receipts.fetch(
                 [
                   %{
                     gas: 9000,
                     hash: transaction_hash
                   }
                 ],
                 json_rpc_named_arguments
               )
    end

    test "with errors return all errors", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn json, _options ->
        assert length(json) == 5

        {:ok,
         [
           %{id: 0, result: %{}},
           # :ok, :ok
           %{id: 1, result: %{}},
           # :error, :ok
           %{id: 2, error: %{code: 2}},
           # :ok, :error
           %{id: 3, result: %{}},
           # :error, :error
           %{id: 4, error: %{code: 4}}
         ]}
      end)

      assert {:error,
              [
                %{code: 4, data: %{gas: 4, hash: "0x4"}},
                %{code: 2, data: %{gas: 2, hash: "0x2"}}
              ]} =
               Receipts.fetch(
                 [
                   %{gas: 0, hash: "0x0"},
                   %{gas: 1, hash: "0x1"},
                   %{gas: 2, hash: "0x2"},
                   %{gas: 3, hash: "0x3"},
                   %{gas: 4, hash: "0x4"}
                 ],
                 moxed_json_rpc_named_arguments
               )
    end
  end
end
