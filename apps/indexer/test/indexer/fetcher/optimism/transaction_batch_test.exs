if Application.get_env(:explorer, :chain_type) == :optimism do
  defmodule Indexer.Fetcher.Optimism.TransactionBatchTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import Mox

    alias Indexer.Fetcher.Optimism.TransactionBatch

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    describe "get_block_numbers_by_hashes/2" do
      test "processes empty list" do
        assert TransactionBatch.get_block_numbers_by_hashes([], %{}) == %{}
      end

      test "processes list of hashes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        hashA = <<1::256>>

        hashB =
          <<48, 120, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
            32, 32, 32, 32, 32>>

        hashes = [
          hashA,
          hashB
        ]

        expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                       %{
                                                         id: id1,
                                                         method: "eth_getBlockByHash",
                                                         params: [
                                                           %Explorer.Chain.Hash{byte_count: 32, bytes: hashA},
                                                           false
                                                         ]
                                                       },
                                                       %{
                                                         id: id2,
                                                         method: "eth_getBlockByHash",
                                                         params: [
                                                           %Explorer.Chain.Hash{byte_count: 32, bytes: hashB},
                                                           false
                                                         ]
                                                       }
                                                     ],
                                                     _options ->
          {:ok,
           [
             %{
               id: id1,
               jsonrpc: "2.0",
               result: %{"number" => 1, "hash" => "0x0000000000000000000000000000000000000000000000000000000000000001"}
             },
             %{
               id: id2,
               jsonrpc: "2.0",
               result: %{"number" => 2, "hash" => "0x3078202020202020202020202020202020202020202020202020202020202020"}
             }
           ]}
        end)

        assert %{hashA => 1, hashB => 2} ==
                 TransactionBatch.get_block_numbers_by_hashes(hashes, json_rpc_named_arguments)
      end
    end
  end
end
