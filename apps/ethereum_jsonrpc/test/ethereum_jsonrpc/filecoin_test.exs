defmodule EthereumJSONRPC.FilecoinTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.Filecoin

  setup :verify_on_exit!

  describe "fetch_block_internal_transactions/2" do
    setup do
      initial_env = Application.get_all_env(:ethereum_jsonrpc)
      old_env = Application.get_env(:explorer, :chain_type)

      Application.put_env(:explorer, :chain_type, :filecoin)

      on_exit(fn ->
        Application.put_all_env([{:ethereum_jsonrpc, initial_env}])
        Application.put_env(:explorer, :chain_type, old_env)
      end)

      EthereumJSONRPC.Case.Filecoin.Mox.setup()
    end

    setup :verify_on_exit!

    test "is supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_663_376
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity]}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "type" => "call",
                 "subtraces" => 0,
                 "traceAddress" => [],
                 "action" => %{
                   "callType" => "call",
                   "from" => "0xff0000000000000000000000000000000021cc23",
                   "to" => "0xff000000000000000000000000000000001a34e5",
                   "gas" => "0x1891a7d",
                   "value" => "0x0",
                   "input" =>
                     "0x868e10c400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000051000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000f2850d8182004081820d58c0960ee115a7a4b6f2fd36a83da26c608d49e4160a3737655d0f637b81be81b018539809d35519b0b75ca06304b3b4d40c810e50b954e82c5119a8b4a64c3e762a7ae8a2d465d1cd5bf096c87c56ab0da879568378e5a2368c902eea9898cf1e2a1974ddb479ec6257b69aca7734d3b3e1e70428c77f9e528ffcb3dc3f050f0193c2cc005927a765c39a4931d67fb29aaba6e99f2c7d2566b98fdbf30d6e15a2bbd63b8fa059cfad231ccba1d8964542b50419eaad4bc442d3a1dc1f41941944c11a0037e5f45820d41114bb6abbf966c2528f5705447a53ee37b7055cd4478503ea5eaf1fe165c60000000000000000000000000000"
                 },
                 "result" => %{
                   "gasUsed" => "0x14696c1",
                   "output" =>
                     "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000"
                 },
                 "blockHash" => "0xbeef70ac3db42f10dd1eb03f5f0640557acd72db61357cf3c4f47945d8beab79",
                 "blockNumber" => 3_663_376,
                 "transactionHash" => "0xf37d8b8bf67df3ddaa264e22322d2b092e390ed33f1ab14c8a136b2767979254",
                 "transactionPosition" => 1
               },
               %{
                 "type" => "call",
                 "subtraces" => 0,
                 "traceAddress" => [
                   1
                 ],
                 "action" => %{
                   "callType" => "call",
                   "from" => "0xff000000000000000000000000000000002c2c61",
                   "to" => "0xff00000000000000000000000000000000000004",
                   "gas" => "0x2c6aae6",
                   "value" => "0x0",
                   "input" =>
                     "0x868e10c40000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000"
                 },
                 "result" => %{
                   "gasUsed" => "0x105fb2",
                   "output" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000051000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000578449007d2903b8000000004a000190f76c1adff180004c00907e2dd41a18e7c7a7f2bd82581a0001916cb98a2c3dfb67a389a588fb0e593f762dd6c9195851235601fba7e16707ee65746d4671e80aa2bb15bc7d6ebe3b000000000000000000"
                 },
                 "blockHash" => "0xbeef70ac3db42f10dd1eb03f5f0640557acd72db61357cf3c4f47945d8beab79",
                 "blockNumber" => 3_663_376,
                 "transactionHash" => "0xbc62a61e0be0e8f6ae09e21ad10f6d79c9a8b8ebc46f8ce076dc0dbe1d6ed4a9",
                 "transactionPosition" => 21
               }
             ]
           }
         ]}
      end)

      assert {:ok,
              [
                %{
                  block_number: ^block_number,
                  transaction_index: 21,
                  transaction_hash: "0xbc62a61e0be0e8f6ae09e21ad10f6d79c9a8b8ebc46f8ce076dc0dbe1d6ed4a9",
                  index: 0,
                  trace_address: [1],
                  type: "call",
                  call_type: "call",
                  from_address_hash: "0xff000000000000000000000000000000002c2c61",
                  to_address_hash: "0xff00000000000000000000000000000000000004",
                  gas: 46_574_310,
                  gas_used: 1_073_074,
                  input:
                    "0x868e10c40000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000",
                  output:
                    "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000051000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000578449007d2903b8000000004a000190f76c1adff180004c00907e2dd41a18e7c7a7f2bd82581a0001916cb98a2c3dfb67a389a588fb0e593f762dd6c9195851235601fba7e16707ee65746d4671e80aa2bb15bc7d6ebe3b000000000000000000",
                  value: 0
                },
                %{
                  block_number: ^block_number,
                  transaction_index: 1,
                  transaction_hash: "0xf37d8b8bf67df3ddaa264e22322d2b092e390ed33f1ab14c8a136b2767979254",
                  index: 0,
                  trace_address: [],
                  type: "call",
                  call_type: "call",
                  from_address_hash: "0xff0000000000000000000000000000000021cc23",
                  to_address_hash: "0xff000000000000000000000000000000001a34e5",
                  gas: 25_762_429,
                  gas_used: 21_403_329,
                  input:
                    "0x868e10c400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000051000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000f2850d8182004081820d58c0960ee115a7a4b6f2fd36a83da26c608d49e4160a3737655d0f637b81be81b018539809d35519b0b75ca06304b3b4d40c810e50b954e82c5119a8b4a64c3e762a7ae8a2d465d1cd5bf096c87c56ab0da879568378e5a2368c902eea9898cf1e2a1974ddb479ec6257b69aca7734d3b3e1e70428c77f9e528ffcb3dc3f050f0193c2cc005927a765c39a4931d67fb29aaba6e99f2c7d2566b98fdbf30d6e15a2bbd63b8fa059cfad231ccba1d8964542b50419eaad4bc442d3a1dc1f41941944c11a0037e5f45820d41114bb6abbf966c2528f5705447a53ee37b7055cd4478503ea5eaf1fe165c60000000000000000000000000000",
                  output:
                    "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000",
                  value: 0
                }
              ]} =
               Filecoin.fetch_block_internal_transactions(
                 [
                   block_number
                 ],
                 json_rpc_named_arguments
               )
    end

    test "parses smart-contract creation", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_663_377
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity]}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "type" => "create",
                 "subtraces" => 0,
                 "traceAddress" => [
                   0
                 ],
                 "action" => %{
                   "from" => "0xff00000000000000000000000000000000000004",
                   "gas" => "0x53cf101",
                   "value" => "0x0",
                   "init" => "0xfe"
                 },
                 "result" => %{
                   "address" => "0xff000000000000000000000000000000002d44e6",
                   "gasUsed" => "0x1be32fc",
                   "code" => "0xfe"
                 },
                 "blockHash" => "0xbeef70ac3db42f10dd1eb03f5f0640557acd72db61357cf3c4f47945d8beab79",
                 "blockNumber" => 3_663_377,
                 "transactionHash" => "0x86ccda9dc76bd37c7201a6da1e10260bf984590efc6b221635c8dd33cc520067",
                 "transactionPosition" => 18
               }
             ]
           }
         ]}
      end)

      assert {:ok,
              [
                %{
                  block_number: ^block_number,
                  transaction_index: 18,
                  transaction_hash: "0x86ccda9dc76bd37c7201a6da1e10260bf984590efc6b221635c8dd33cc520067",
                  index: 0,
                  trace_address: [0],
                  type: "create",
                  from_address_hash: "0xff00000000000000000000000000000000000004",
                  created_contract_address_hash: "0xff000000000000000000000000000000002d44e6",
                  gas: 87_879_937,
                  gas_used: 29_242_108,
                  init: "0xfe",
                  created_contract_code: "0xfe",
                  value: 0
                }
              ]} =
               Filecoin.fetch_block_internal_transactions(
                 [
                   block_number
                 ],
                 json_rpc_named_arguments
               )
    end
  end
end
