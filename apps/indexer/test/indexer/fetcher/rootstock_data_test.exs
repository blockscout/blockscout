defmodule Indexer.Fetcher.RootstockDataTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Indexer.Fetcher.RootstockData

  setup :verify_on_exit!
  setup :set_mox_global

  if Application.compile_env(:explorer, :chain_type) == "rsk" do
    test "do not start when all old blocks are fetched", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      RootstockData.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :timer.sleep(300)

      assert [{Indexer.Fetcher.RootstockData, :undefined, :worker, [Indexer.Fetcher.RootstockData]} | _] =
               RootstockData.Supervisor |> Supervisor.which_children()
    end

    test "stops when all old blocks are fetched", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_a = insert(:block)
      block_b = insert(:block)

      block_a_number_string = integer_to_quantity(block_a.number)
      block_b_number_string = integer_to_quantity(block_b.number)

      EthereumJSONRPC.Mox
      |> stub(:json_rpc, fn requests, _options ->
        {:ok,
         Enum.map(requests, fn
           %{id: id, method: "eth_getBlockByNumber", params: [^block_a_number_string, false]} ->
             %{
               id: id,
               result: %{
                 "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                 "difficulty" => "0x6bc767dd80781",
                 "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                 "gasLimit" => "0x7a121d",
                 "gasUsed" => "0x79cbe9",
                 "hash" => to_string(block_a.hash),
                 "logsBloom" =>
                   "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                 "miner" => to_string(block_a.miner),
                 "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                 "nonce" => "0x0946e5f01fce12bc",
                 "number" => block_a_number_string,
                 "parentHash" => to_string(block_a.parent_hash),
                 "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                 "sealFields" => [
                   "0xa0da53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "0x880946e5f01fce12bc"
                 ],
                 "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                 "size" => "0x544c",
                 "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                 "timestamp" => "0x5c8bc76e",
                 "totalDifficulty" => "0x201a42c35142ae94458",
                 "transactions" => [],
                 "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                 "uncles" => [],
                 "withdrawals" => [],
                 "minimumGasPrice" => "0x0",
                 "bitcoinMergedMiningHeader" =>
                   "0x00006d20ffd048280094a6ea0851d854036aacaa25ee0f23f0040200000000000000000078d2638fe0b4477c54601e6449051afba8228e0a88ff06b0c91f091fd34d5da57487c76402610517372c2fe9",
                 "bitcoinMergedMiningCoinbaseTransaction" =>
                   "0x00000000000000805bf0dc9203da49a3b4e3ec913806e43102cc07db991272dc8b7018da57eb5abe59a32d070000ffffffff03449a4d26000000001976a914536ffa992491508dca0354e52f32a3a7a679a53a88ac00000000000000002b6a2952534b424c4f434b3ad2508d21d28c8f89d495923c0758ec3f64bd6755b4ec416f5601312600542a400000000000000000266a24aa21a9ed4ae42ea6dca2687aaed665714bf58b055c4e11f2fb038605930d630b49ad7b9d00000000",
                 "bitcoinMergedMiningMerkleProof" =>
                   "0x8e5a4ba74eb4eb2f9ad4cabc2913aeed380a5becf7cd4d513341617efb798002bd83a783c31c66a8a8f6cc56c071c2d471cb610e3dc13054b9d216021d8c7e9112f622564449ebedcedf7d4ccb6fe0ffac861b7ed1446c310813cdf712e1e6add28b1fe1c0ae5e916194ba4f285a9340aba41e91bf847bf31acf37a9623a04a2348a37ab9faa5908122db45596bbc03e9c3644b0d4589471c4ff30fc139f3ba50506e9136fa0df799b487494de3e2b3dec937338f1a2e18da057c1f60590a9723672a4355b9914b1d01af9f582d9e856f6e1744be00f268b0b01d559329f7e0685aa63ffeb7c28486d7462292021d1345cddbf7c920ca34bb7aa4c6cdbe068806e35d0db662e7fcda03cb4d779594638c62a1fdd7ec98d1fb6d240d853958abe57561d9b9d0465cf8b9d6ee3c58b0d8b07d6c4c5d8f348e43fe3c06011b6a0008db4e0b16c77ececc3981f9008201cea5939869d648e59a09bd2094b1196ff61126bffb626153deed2563e1745436247c94a85d2947756b606d67633781c99d7",
                 "hashForMergedMining" => "0xd2508d21d28c8f89d495923c0758ec3f64bd6755b4ec416f5601312600542a40"
               }
             }

           %{id: id, method: "eth_getBlockByNumber", params: [^block_b_number_string, false]} ->
             %{
               id: id,
               result: %{
                 "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                 "difficulty" => "0x6bc767dd80781",
                 "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                 "gasLimit" => "0x7a121d",
                 "gasUsed" => "0x79cbe9",
                 "hash" => to_string(block_b.hash),
                 "logsBloom" =>
                   "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                 "miner" => to_string(block_b.miner),
                 "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                 "nonce" => "0x0946e5f01fce12bc",
                 "number" => block_b_number_string,
                 "parentHash" => to_string(block_b.parent_hash),
                 "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                 "sealFields" => [
                   "0xa0da53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "0x880946e5f01fce12bc"
                 ],
                 "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                 "size" => "0x544c",
                 "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                 "timestamp" => "0x5c8bc76e",
                 "totalDifficulty" => "0x201a42c35142ae94458",
                 "transactions" => [],
                 "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                 "uncles" => [],
                 "withdrawals" => [],
                 "minimumGasPrice" => "0x1",
                 "bitcoinMergedMiningHeader" =>
                   "0x00006d20ffd048280094a6ea0851d854036aacaa25ee0f23f0040200000000000000000078d2638fe0b4477c54601e6449051afba8228e0a88ff06b0c91f091fd34d5da57487c76402610517372c2fe9",
                 "bitcoinMergedMiningCoinbaseTransaction" =>
                   "0x00000000000000805bf0dc9203da49a3b4e3ec913806e43102cc07db991272dc8b7018da57eb5abe59a32d070000ffffffff03449a4d26000000001976a914536ffa992491508dca0354e52f32a3a7a679a53a88ac00000000000000002b6a2952534b424c4f434b3ad2508d21d28c8f89d495923c0758ec3f64bd6755b4ec416f5601312600542a400000000000000000266a24aa21a9ed4ae42ea6dca2687aaed665714bf58b055c4e11f2fb038605930d630b49ad7b9d00000000",
                 "bitcoinMergedMiningMerkleProof" =>
                   "0x8e5a4ba74eb4eb2f9ad4cabc2913aeed380a5becf7cd4d513341617efb798002bd83a783c31c66a8a8f6cc56c071c2d471cb610e3dc13054b9d216021d8c7e9112f622564449ebedcedf7d4ccb6fe0ffac861b7ed1446c310813cdf712e1e6add28b1fe1c0ae5e916194ba4f285a9340aba41e91bf847bf31acf37a9623a04a2348a37ab9faa5908122db45596bbc03e9c3644b0d4589471c4ff30fc139f3ba50506e9136fa0df799b487494de3e2b3dec937338f1a2e18da057c1f60590a9723672a4355b9914b1d01af9f582d9e856f6e1744be00f268b0b01d559329f7e0685aa63ffeb7c28486d7462292021d1345cddbf7c920ca34bb7aa4c6cdbe068806e35d0db662e7fcda03cb4d779594638c62a1fdd7ec98d1fb6d240d853958abe57561d9b9d0465cf8b9d6ee3c58b0d8b07d6c4c5d8f348e43fe3c06011b6a0008db4e0b16c77ececc3981f9008201cea5939869d648e59a09bd2094b1196ff61126bffb626153deed2563e1745436247c94a85d2947756b606d67633781c99d7",
                 "hashForMergedMining" => "0xd2508d21d28c8f89d495923c0758ec3f64bd6755b4ec416f5601312600542a40"
               }
             }
         end)}
      end)

      pid = RootstockData.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert [{Indexer.Fetcher.RootstockData, worker_pid, :worker, [Indexer.Fetcher.RootstockData]} | _] =
               RootstockData.Supervisor |> Supervisor.which_children()

      assert is_pid(worker_pid)

      :timer.sleep(300)

      assert [{Indexer.Fetcher.RootstockData, :undefined, :worker, [Indexer.Fetcher.RootstockData]} | _] =
               RootstockData.Supervisor |> Supervisor.which_children()

      # Terminates the process so it finishes all Ecto processes.
      GenServer.stop(pid)
    end
  end
end
