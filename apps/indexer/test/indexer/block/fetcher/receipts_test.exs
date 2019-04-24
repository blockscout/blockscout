defmodule Indexer.Block.Fetcher.ReceiptsTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias Indexer.Block.Fetcher
  alias Indexer.Block.Fetcher.Receipts

  @moduletag capture_log: true

  setup :set_mox_global

  setup :verify_on_exit!

  describe "fetch/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{
        block_fetcher: %Fetcher{
          json_rpc_named_arguments: json_rpc_named_arguments,
          receipts_concurrency: 10
        }
      }
    end

    @tag :no_parity
    @tag :no_geth
    test "fetches logs setting their blocks if they're null", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => nil,
                 "blockNumber" => nil,
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "logs" => [
                   %{
                     "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                     "blockHash" => nil,
                     "blockNumber" => nil,
                     "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                     "logIndex" => "0x0",
                     "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
                     "transactionHash" => "0x43bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                     "transactionIndex" => "0x0",
                     "transactionLogIndex" => "0x0",
                     "type" => "mined"
                   }
                 ],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => "0x43bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                 "transactionIndex" => "0x0"
               }
             },
             %{
               id: 1,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                 "blockNumber" => "0x25",
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0xc512",
                 "gasUsed" => "0xc512",
                 "logs" => [
                   %{
                     "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "blockNumber" => "0x25",
                     "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                     "logIndex" => "0x0",
                     "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
                     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                     "transactionIndex" => "0x0",
                     "transactionLogIndex" => "0x0",
                     "type" => "mined"
                   }
                 ],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
      end

      transaction_params = [
        %{
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          block_number: 46147,
          from_address_hash: "0xa1e4380a3b1f749673e270229993ee55f35663b4",
          gas: 21000,
          gas_price: 50_000_000_000_000,
          hash: "0x43bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          index: 0,
          input: "0x",
          nonce: 0,
          r: 61_965_845_294_689_009_770_156_372_156_374_760_022_787_886_965_323_743_865_986_648_153_755_601_564_112,
          s: 31_606_574_786_494_953_692_291_101_914_709_926_755_545_765_281_581_808_821_704_454_381_804_773_090_106,
          to_address_hash: "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
          v: 28,
          value: 31337,
          transaction_index: 0
        },
        %{
          block_hash: "0xf7b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          block_number: 46148,
          from_address_hash: "0xa1e4380a3b1f749673e270229993ee55f35663b4",
          gas: 21000,
          gas_price: 50_000_000_000_000,
          hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          index: 0,
          input: "0x",
          nonce: 0,
          r: 61_965_845_294_689_009_770_156_372_156_374_760_022_787_886_965_323_743_865_986_648_153_755_601_564_112,
          s: 31_606_574_786_494_953_692_291_101_914_709_926_755_545_765_281_581_808_821_704_454_381_804_773_090_106,
          to_address_hash: "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
          v: 28,
          value: 31337,
          transaction_index: 0
        }
      ]

      {:ok, %{logs: logs}} = Receipts.fetch(block_fetcher, transaction_params)

      assert Enum.find(logs, fn log ->
               log[:transaction_hash] == "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5" &&
                 log[:block_number] == 37
             end)

      assert Enum.find(logs, fn log ->
               log[:transaction_hash] == "0x43bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5" &&
                 log[:block_number] == 46147
             end)
    end
  end
end
