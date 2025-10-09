defmodule EthereumJSONRPC.GethTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.Geth

  setup :verify_on_exit!

  describe "fetch_internal_transactions/2" do
    # Infura Mainnet does not support debug_traceTransaction, so this cannot be tested expect in Mox
    setup do
      initial_env = Application.get_all_env(:ethereum_jsonrpc)
      on_exit(fn -> Application.put_all_env([{:ethereum_jsonrpc, initial_env}]) end)
      EthereumJSONRPC.Case.Geth.Mox.setup()
    end

    setup :verify_on_exit!

    # Data taken from Rinkeby
    test "is supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      transaction_index = 13
      transaction_hash = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
      tracer = File.read!("priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js")

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^transaction_hash, %{"tracer" => ^tracer}]}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "traceAddress" => [],
                 "type" => "call",
                 "callType" => "call",
                 "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                 "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                 "gas" => "0x8600",
                 "gasUsed" => "0x7d37",
                 "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                 "output" => "0x",
                 "value" => "0x174876e800"
               }
             ]
           }
         ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "js", debug_trace_timeout: "5s")

      assert {:ok,
              [
                %{
                  block_number: ^block_number,
                  transaction_index: ^transaction_index,
                  transaction_hash: ^transaction_hash,
                  index: 0,
                  trace_address: [],
                  type: "call",
                  call_type: "call",
                  from_address_hash: "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                  to_address_hash: "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                  gas: 34304,
                  gas_used: 32055,
                  input: "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                  output: "0x",
                  value: 100_000_000_000
                }
              ]} =
               Geth.fetch_internal_transactions(
                 [
                   %{
                     block_number: block_number,
                     transaction_index: transaction_index,
                     hash_data: transaction_hash
                   }
                 ],
                 json_rpc_named_arguments
               )
    end

    test "call_tracer contract calls results are the same as js tracer", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      transaction_hash = "0xb342cafc6ac552c3be2090561453204c8784caf025ac8267320834e4cd163d96"
      block_number = 3_287_375
      transaction_index = 13

      transaction_params = %{
        block_number: block_number,
        transaction_index: transaction_index,
        hash_data: transaction_hash
      }

      tracer = File.read!("priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js")

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "calls" => [
                   %{
                     "calls" => [
                       %{
                         "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "gas" => "0x12816",
                         "gasUsed" => "0x229e",
                         "input" =>
                           "0xa9059cbb0000000000000000000000009507c04b10486547584c37bcbd931b2a4fee9a4100000000000000000000000000000000000000000000000322a0aedb1fe2c7e6",
                         "output" => "0x",
                         "to" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
                         "type" => "CALL",
                         "value" => "0x0"
                       },
                       %{
                         "calls" => [
                           %{
                             "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                             "gas" => "0xfbb8",
                             "gasUsed" => "0x211",
                             "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                             "output" => "0x",
                             "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                             "type" => "DELEGATECALL"
                           }
                         ],
                         "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "gas" => "0x1029c",
                         "gasUsed" => "0x523",
                         "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "output" => "0x",
                         "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                         "type" => "STATICCALL"
                       },
                       %{
                         "calls" => [
                           %{
                             "calls" => [
                               %{
                                 "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                                 "gas" => "0xe3e3",
                                 "gasUsed" => "0x259c",
                                 "input" =>
                                   "0xa9059cbb00000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f564000000000000000000000000000000000000000000000000000000014e53ad37c",
                                 "output" => "0x",
                                 "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                                 "type" => "DELEGATECALL"
                               }
                             ],
                             "from" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                             "gas" => "0xea6a",
                             "gasUsed" => "0x28b1",
                             "input" =>
                               "0xa9059cbb00000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f564000000000000000000000000000000000000000000000000000000014e53ad37c",
                             "output" => "0x",
                             "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                             "type" => "CALL",
                             "value" => "0x0"
                           }
                         ],
                         "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "gas" => "0xfa71",
                         "gasUsed" => "0x3627",
                         "input" =>
                           "0xfa461e3300000000000000000000000000000000000000000000000000000014e53ad37cfffffffffffffffffffffffffffffffffffffffffffffffcdd5f5124e01d381a000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000014e53ad37c00000000000000000000000000000000000000000000000322a0aedb1fe2c7e600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000",
                         "output" => "0x",
                         "to" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                         "type" => "CALL",
                         "value" => "0x0"
                       },
                       %{
                         "calls" => [
                           %{
                             "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                             "gas" => "0xbcc4",
                             "gasUsed" => "0x211",
                             "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                             "output" => "0x",
                             "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                             "type" => "DELEGATECALL"
                           }
                         ],
                         "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "gas" => "0xc2a9",
                         "gasUsed" => "0x523",
                         "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                         "output" => "0x",
                         "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                         "type" => "STATICCALL"
                       }
                     ],
                     "from" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                     "gas" => "0x185b2",
                     "gasUsed" => "0xd38e",
                     "input" =>
                       "0x128acb080000000000000000000000009507c04b10486547584c37bcbd931b2a4fee9a410000000000000000000000000000000000000000000000000000000000000001fffffffffffffffffffffffffffffffffffffffffffffffcdd5f5124e01d381a00000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000014e53ad37c00000000000000000000000000000000000000000000000322a0aedb1fe2c7e600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000",
                     "output" => "0x",
                     "to" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                     "type" => "CALL",
                     "value" => "0x0"
                   }
                 ],
                 "from" => "0x56d0c33e5e8cb6390cebd7369d2fe7e7870a04e0",
                 "gas" => "0x1a8c6",
                 "gasUsed" => "0xf1f6",
                 "input" =>
                   "0x33000000000000000014e53ad37c0000000322a0aedb1fe2c7e6010201f4ff010088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48c02aaa39b223fe8d0a0e5c4f27ead9083c756cc203",
                 "output" => "0x",
                 "time" => "48.391824ms",
                 "to" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                 "type" => "CALL",
                 "value" => "0xfa72c6"
               }
             }
           ]}
      end)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => ^tracer}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "callType" => "call",
                   "from" => "0x56d0c33e5e8cb6390cebd7369d2fe7e7870a04e0",
                   "gas" => "0x1a8c6",
                   "gasUsed" => "0xf1f6",
                   "input" =>
                     "0x33000000000000000014e53ad37c0000000322a0aedb1fe2c7e6010201f4ff010088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48c02aaa39b223fe8d0a0e5c4f27ead9083c756cc203",
                   "output" => "0x",
                   "to" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                   "traceAddress" => [],
                   "type" => "call",
                   "value" => "0xfa72c6"
                 },
                 %{
                   "callType" => "call",
                   "from" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                   "gas" => "0x185b2",
                   "gasUsed" => "0xd38e",
                   "input" =>
                     "0x128acb080000000000000000000000009507c04b10486547584c37bcbd931b2a4fee9a410000000000000000000000000000000000000000000000000000000000000001fffffffffffffffffffffffffffffffffffffffffffffffcdd5f5124e01d381a00000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000014e53ad37c00000000000000000000000000000000000000000000000322a0aedb1fe2c7e600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000",
                   "output" => "0x",
                   "to" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "traceAddress" => [0],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "call",
                   "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "gas" => "0x12816",
                   "gasUsed" => "0x229e",
                   "input" =>
                     "0xa9059cbb0000000000000000000000009507c04b10486547584c37bcbd931b2a4fee9a4100000000000000000000000000000000000000000000000322a0aedb1fe2c7e6",
                   "output" => "0x",
                   "to" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
                   "traceAddress" => [0, 0],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "staticcall",
                   "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "gas" => "0x1029c",
                   "gasUsed" => "0x523",
                   "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "output" => "0x",
                   "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "traceAddress" => [0, 1],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "delegatecall",
                   "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "gas" => "0xfbb8",
                   "gasUsed" => "0x211",
                   "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "output" => "0x",
                   "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                   "traceAddress" => [0, 1, 0],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "call",
                   "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "gas" => "0xfa71",
                   "gasUsed" => "0x3627",
                   "input" =>
                     "0xfa461e3300000000000000000000000000000000000000000000000000000014e53ad37cfffffffffffffffffffffffffffffffffffffffffffffffcdd5f5124e01d381a000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000014e53ad37c00000000000000000000000000000000000000000000000322a0aedb1fe2c7e600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000",
                   "output" => "0x",
                   "to" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                   "traceAddress" => [0, 2],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "call",
                   "from" => "0x9507c04b10486547584c37bcbd931b2a4fee9a41",
                   "gas" => "0xea6a",
                   "gasUsed" => "0x28b1",
                   "input" =>
                     "0xa9059cbb00000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f564000000000000000000000000000000000000000000000000000000014e53ad37c",
                   "output" => "0x",
                   "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "traceAddress" => [0, 2, 0],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "delegatecall",
                   "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "gas" => "0xe3e3",
                   "gasUsed" => "0x259c",
                   "input" =>
                     "0xa9059cbb00000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f564000000000000000000000000000000000000000000000000000000014e53ad37c",
                   "output" => "0x",
                   "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                   "traceAddress" => [0, 2, 0, 0],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "staticcall",
                   "from" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "gas" => "0xc2a9",
                   "gasUsed" => "0x523",
                   "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "output" => "0x",
                   "to" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "traceAddress" => [0, 3],
                   "type" => "call",
                   "value" => "0x0"
                 },
                 %{
                   "callType" => "delegatecall",
                   "from" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   "gas" => "0xbcc4",
                   "gasUsed" => "0x211",
                   "input" => "0x70a0823100000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
                   "output" => "0x",
                   "to" => "0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf",
                   "traceAddress" => [0, 3, 0],
                   "type" => "call",
                   "value" => "0x0"
                 }
               ]
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      call_tracer_internal_transactions =
        Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "js", debug_trace_timeout: "5s")

      assert call_tracer_internal_transactions ==
               Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)
    end

    test "call_tracer contract creation results are the same as js tracer", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      transaction_hash = "0xb342cafc6ac552c3be2090561453204c8784caf025ac8267320834e4cd163d96"
      block_number = 3_287_375
      transaction_index = 13

      transaction_params = %{
        block_number: block_number,
        transaction_index: transaction_index,
        hash_data: transaction_hash
      }

      tracer = File.read!("priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js")

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "type" => "CREATE",
                 "from" => "0x117b358218da5a4f647072ddb50ded038ed63d17",
                 "to" => "0x205a6b72ce16736c9d87172568a9c0cb9304de0d",
                 "value" => "0x0",
                 "gas" => "0x106f5",
                 "gasUsed" => "0x106f5",
                 "input" =>
                   "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
                 "output" =>
                   "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033"
               }
             }
           ]}
      end)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => ^tracer}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "type" => "create",
                   "from" => "0x117b358218da5a4f647072ddb50ded038ed63d17",
                   "init" =>
                     "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
                   "createdContractAddressHash" => "0x205a6b72ce16736c9d87172568a9c0cb9304de0d",
                   "createdContractCode" =>
                     "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
                   "traceAddress" => [],
                   "value" => "0x0",
                   "gas" => "0x106f5",
                   "gasUsed" => "0x106f5"
                 }
               ]
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      call_tracer_internal_transactions =
        Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "js", debug_trace_timeout: "5s")

      assert call_tracer_internal_transactions ==
               Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)
    end

    test "successfully handle single stop opcode from call_tracer", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      transaction_hash = "0xb342cafc6ac552c3be2090561453204c8784caf025ac8267320834e4cd163d96"
      block_number = 3_287_375
      transaction_index = 13

      transaction_params = %{
        block_number: block_number,
        transaction_index: transaction_index,
        hash_data: transaction_hash
      }

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "type" => "STOP",
                 "from" => "0x0000000000000000000000000000000000000000",
                 "value" => "0x0",
                 "gas" => "0x0",
                 "gasUsed" => "0x5842"
               }
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      assert {:ok,
              [
                %{
                  block_number: 3_287_375,
                  error: "execution stopped",
                  from_address_hash: "0x0000000000000000000000000000000000000000",
                  input: "0x",
                  trace_address: [],
                  transaction_hash: "0xb342cafc6ac552c3be2090561453204c8784caf025ac8267320834e4cd163d96",
                  transaction_index: 13,
                  type: "stop",
                  value: 0
                }
              ]} = Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)
    end

    test "uppercase type parsing result is the same as lowercase", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      transaction_hash = "0xb342cafc6ac552c3be2090561453204c8784caf025ac8267320834e4cd163d96"
      block_number = 3_287_375
      transaction_index = 13

      transaction_params = %{
        block_number: block_number,
        transaction_index: transaction_index,
        hash_data: transaction_hash
      }

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "type" => "CREATE",
                 "from" => "0x117b358218da5a4f647072ddb50ded038ed63d17",
                 "to" => "0x205a6b72ce16736c9d87172568a9c0cb9304de0d",
                 "value" => "0x0",
                 "gas" => "0x106f5",
                 "gasUsed" => "0x106f5",
                 "input" =>
                   "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
                 "output" =>
                   "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033"
               }
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      uppercase_result = Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "type" => "create",
                 "from" => "0x117b358218da5a4f647072ddb50ded038ed63d17",
                 "to" => "0x205a6b72ce16736c9d87172568a9c0cb9304de0d",
                 "value" => "0x0",
                 "gas" => "0x106f5",
                 "gasUsed" => "0x106f5",
                 "input" =>
                   "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
                 "output" =>
                   "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033"
               }
             }
           ]}
      end)

      lowercase_result = Geth.fetch_internal_transactions([transaction_params], json_rpc_named_arguments)

      assert uppercase_result == lowercase_result
    end
  end

  describe "fetch_block_internal_transactions/1" do
    setup do
      EthereumJSONRPC.Case.Geth.Mox.setup()
    end

    test "is supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      transaction_hash = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity, %{"tracer" => "callTracer"}]}],
                                                _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                       "type" => "DELEGATECALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => "0x4200000000000000000000000000000000000015",
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => transaction_hash
               }
             ]
           }
         ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      assert {:ok,
              [
                %{
                  block_number: 3_287_375,
                  call_type: "call",
                  from_address_hash: "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                  gas: 1_000_000,
                  gas_used: 46841,
                  index: 0,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x4200000000000000000000000000000000000015",
                  trace_address: [],
                  transaction_hash: ^transaction_hash,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                },
                %{
                  block_number: 3_287_375,
                  call_type: "delegatecall",
                  from_address_hash: "0x4200000000000000000000000000000000000015",
                  gas: 956_988,
                  gas_used: 18984,
                  index: 1,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                  trace_address: [0],
                  transaction_hash: ^transaction_hash,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                }
              ]} = Geth.fetch_block_internal_transactions([block_number], json_rpc_named_arguments)
    end

    test "works for multiple blocks request", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number_1 = 3_287_375
      block_number_2 = 3_287_376
      block_quantity_1 = EthereumJSONRPC.integer_to_quantity(block_number_1)
      block_quantity_2 = EthereumJSONRPC.integer_to_quantity(block_number_2)
      transaction_hash_1 = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
      transaction_hash_2 = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5b"

      expect(EthereumJSONRPC.Mox, :json_rpc, fn
        [
          %{id: id_1, params: [^block_quantity_1, %{"tracer" => "callTracer"}]},
          %{id: id_2, params: [^block_quantity_2, %{"tracer" => "callTracer"}]}
        ],
        _ ->
          {:ok,
           [
             %{
               id: id_1,
               result: [
                 %{
                   "result" => %{
                     "calls" => [
                       %{
                         "from" => "0x4200000000000000000000000000000000000015",
                         "gas" => "0xe9a3c",
                         "gasUsed" => "0x4a28",
                         "input" =>
                           "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                         "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                         "type" => "DELEGATECALL",
                         "value" => "0x0"
                       }
                     ],
                     "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                     "gas" => "0xf4240",
                     "gasUsed" => "0xb6f9",
                     "input" =>
                       "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                     "to" => "0x4200000000000000000000000000000000000015",
                     "type" => "CALL",
                     "value" => "0x0"
                   },
                   "txHash" => transaction_hash_1
                 }
               ]
             },
             %{
               id: id_2,
               result: [
                 %{
                   "result" => %{
                     "calls" => [
                       %{
                         "from" => "0x4200000000000000000000000000000000000015",
                         "gas" => "0xe9a3c",
                         "gasUsed" => "0x4a28",
                         "input" =>
                           "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                         "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                         "type" => "DELEGATECALL",
                         "value" => "0x0"
                       }
                     ],
                     "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                     "gas" => "0xf4240",
                     "gasUsed" => "0xb6f9",
                     "input" =>
                       "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                     "to" => "0x4200000000000000000000000000000000000015",
                     "type" => "CALL",
                     "value" => "0x0"
                   },
                   "txHash" => transaction_hash_2
                 }
               ]
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      assert {:ok,
              [
                %{
                  block_number: ^block_number_1,
                  call_type: "call",
                  from_address_hash: "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                  gas: 1_000_000,
                  gas_used: 46841,
                  index: 0,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x4200000000000000000000000000000000000015",
                  trace_address: [],
                  transaction_hash: ^transaction_hash_1,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                },
                %{
                  block_number: ^block_number_1,
                  call_type: "delegatecall",
                  from_address_hash: "0x4200000000000000000000000000000000000015",
                  gas: 956_988,
                  gas_used: 18984,
                  index: 1,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                  trace_address: [0],
                  transaction_hash: ^transaction_hash_1,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                },
                %{
                  block_number: ^block_number_2,
                  call_type: "call",
                  from_address_hash: "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                  gas: 1_000_000,
                  gas_used: 46841,
                  index: 0,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x4200000000000000000000000000000000000015",
                  trace_address: [],
                  transaction_hash: ^transaction_hash_2,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                },
                %{
                  block_number: ^block_number_2,
                  call_type: "delegatecall",
                  from_address_hash: "0x4200000000000000000000000000000000000015",
                  gas: 956_988,
                  gas_used: 18984,
                  index: 1,
                  input:
                    "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                  output: "0x",
                  to_address_hash: "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                  trace_address: [0],
                  transaction_hash: ^transaction_hash_2,
                  transaction_index: 0,
                  type: "call",
                  value: 0
                }
              ]} = Geth.fetch_block_internal_transactions([block_number_1, block_number_2], json_rpc_named_arguments)
    end

    test "result is the same as fetch_internal_transactions/2", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      transaction_hash = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"

      expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn
        [%{id: id, params: [^block_quantity, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "result" => %{
                     "calls" => [
                       %{
                         "from" => "0x4200000000000000000000000000000000000015",
                         "gas" => "0xe9a3c",
                         "gasUsed" => "0x4a28",
                         "input" =>
                           "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                         "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                         "type" => "DELEGATECALL",
                         "value" => "0x0"
                       }
                     ],
                     "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                     "gas" => "0xf4240",
                     "gasUsed" => "0xb6f9",
                     "input" =>
                       "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                     "to" => "0x4200000000000000000000000000000000000015",
                     "type" => "CALL",
                     "value" => "0x0"
                   },
                   "txHash" => transaction_hash
                 }
               ]
             }
           ]}

        [%{id: id, params: [^transaction_hash, %{"tracer" => "callTracer"}]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: %{
                 "calls" => [
                   %{
                     "from" => "0x4200000000000000000000000000000000000015",
                     "gas" => "0xe9a3c",
                     "gasUsed" => "0x4a28",
                     "input" =>
                       "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                     "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                     "type" => "DELEGATECALL",
                     "value" => "0x0"
                   }
                 ],
                 "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                 "gas" => "0xf4240",
                 "gasUsed" => "0xb6f9",
                 "input" =>
                   "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                 "to" => "0x4200000000000000000000000000000000000015",
                 "type" => "CALL",
                 "value" => "0x0"
               }
             }
           ]}
      end)

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      assert Geth.fetch_block_internal_transactions([block_number], json_rpc_named_arguments) ==
               Geth.fetch_internal_transactions(
                 [%{block_number: block_number, transaction_index: 0, hash_data: transaction_hash}],
                 json_rpc_named_arguments
               )
    end
  end

  describe "fetch_pending_transactions/1" do
    @tag :no_geth
    test "fetches pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok,
         %{
           "pending" => %{
             "0xC99f4e9cFf697ca6717ad9cE8bA4A138e0e55109" => %{
               "4656" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0x2b8cfd76a31b942e51b6265c791c860e2840b11f8c2fcfa1c9dfe53dea4c3102",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030af6932dec7c4eaf4b966059e74cc7a1767ba93e62f2d83a7dba5bb785b6efd25e8ab7d2e8798e7ecc27df96380d77a0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000b29e5229b86fbb3a8e45e406b64226c3d49389804a6f7449325fae232d6623000000000000000000000000000000000000000000000000000000000000006097e4c1ed443f430b1d8ad66e565a960fade76e3e177b4120186bdad2fcfa43e134de3abdc0272c9433af94833fec73260c261cf41422e83d958787b62144478bc44ab84d1ddba7a462d355057f3be8ab914a195ac1a637c4fb8503c441dadb45",
                 "nonce" => "0x1230",
                 "r" => "0x81345ae149171f4cb4ab868f0ad637d033c96c4659b190b86a39725c8299c947",
                 "s" => "0x31450678841d7206fa02b564a641420262cc98c8ea0e32c4cb0e97208d3f9feb",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1b",
                 "value" => "0xb5e620f480000"
               },
               "4657" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0x7c3ea924740e996bf552a8dded903ba4258b69d30bf5e6dca6ec86ebc60b8151",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030a25723bca32f88a73abc7eb153cee248effd563d87efe12e08e8a33f74047afc28c30ab9c74bddeb6f0558628b8bf200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020009c56025b2796cdc72f91836278a471590b774462adddd1c87a0b6f84b787990000000000000000000000000000000000000000000000000000000000000060aa53b46c8b57aed7c4c0fdf3f650ec3bb330591929bc813610656882e3203157c22b50d0d0b0316a8712c00fe4f0e0c509613114f5d24c0419a4e8188f2489678b05dccf72a67957785e8e250092c8787f049f7e20b1414a633595a56c98ff82",
                 "nonce" => "0x1231",
                 "r" => "0xee1eb895262d12ef5c4ee3cbf9b36de3903bc3a1343f0a312bd19edacc4bb877",
                 "s" => "0xfcb87efe4c3984a3e1d3f4fb10ce41e59f65e21fbd9206a1648ec73fa0a2206",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1b",
                 "value" => "0xb5e620f480000"
               },
               "4658" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0xe699a58ef4986f2dbdc102acf73b35392aff9ce43fd226000526955e19c0b06e",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000308eb3ed9e686f6bc1fe2d8ce3fea37fb3a66a9c67b91ef15ba6bd7da0eed73288f72577edea2b7ded5855ca8a56b1e01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000051afe6c51e2175a62afbd66d293e8a7509943d5cd6f851f59923a61a186e80000000000000000000000000000000000000000000000000000000000000060a063498e8db2e75e0a193de89ad2947111d677c9501e75c34a64fcee8fe5a7c7607929fc6bce943d64f1039e1d1f325f02d1e5d71f86ca976c9ab79d19f0fd0e530a5210fbe131087ba1f1b3c92abc4a0dd7c8a47c3c276fac3e09bca964fd74",
                 "nonce" => "0x1232",
                 "r" => "0xe95bc86fc32cc591677c7ec9ca49f1dc33a31427235c1c41dbb7a3a957b55599",
                 "s" => "0xe8b41a6440d0fe6d0ec1f40982394a2d641b19b983aad49e45614e5f3a1abc9",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1c",
                 "value" => "0xb5e620f480000"
               }
             }
           },
           "queued" => %{}
         }}
      end)

      assert {:ok,
              [
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0x2b8cfd76a31b942e51b6265c791c860e2840b11f8c2fcfa1c9dfe53dea4c3102",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030af6932dec7c4eaf4b966059e74cc7a1767ba93e62f2d83a7dba5bb785b6efd25e8ab7d2e8798e7ecc27df96380d77a0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000b29e5229b86fbb3a8e45e406b64226c3d49389804a6f7449325fae232d6623000000000000000000000000000000000000000000000000000000000000006097e4c1ed443f430b1d8ad66e565a960fade76e3e177b4120186bdad2fcfa43e134de3abdc0272c9433af94833fec73260c261cf41422e83d958787b62144478bc44ab84d1ddba7a462d355057f3be8ab914a195ac1a637c4fb8503c441dadb45",
                  nonce: 4656,
                  r:
                    58_440_860_745_466_360_584_510_362_592_650_991_653_332_571_230_597_223_185_413_246_840_900_756_818_247,
                  s:
                    22_285_286_687_634_777_993_513_656_263_235_057_426_117_768_584_265_280_722_872_863_042_386_096_267_243,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 27,
                  value: 3_200_000_000_000_000
                },
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0x7c3ea924740e996bf552a8dded903ba4258b69d30bf5e6dca6ec86ebc60b8151",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030a25723bca32f88a73abc7eb153cee248effd563d87efe12e08e8a33f74047afc28c30ab9c74bddeb6f0558628b8bf200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020009c56025b2796cdc72f91836278a471590b774462adddd1c87a0b6f84b787990000000000000000000000000000000000000000000000000000000000000060aa53b46c8b57aed7c4c0fdf3f650ec3bb330591929bc813610656882e3203157c22b50d0d0b0316a8712c00fe4f0e0c509613114f5d24c0419a4e8188f2489678b05dccf72a67957785e8e250092c8787f049f7e20b1414a633595a56c98ff82",
                  nonce: 4657,
                  r:
                    107_704_737_317_141_024_268_971_404_113_297_355_261_066_880_504_936_960_891_977_784_149_226_505_877_623,
                  s:
                    7_144_300_886_174_743_587_831_226_472_052_852_957_529_607_874_128_062_849_708_955_356_153_894_281_734,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 27,
                  value: 3_200_000_000_000_000
                },
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0xe699a58ef4986f2dbdc102acf73b35392aff9ce43fd226000526955e19c0b06e",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000308eb3ed9e686f6bc1fe2d8ce3fea37fb3a66a9c67b91ef15ba6bd7da0eed73288f72577edea2b7ded5855ca8a56b1e01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000051afe6c51e2175a62afbd66d293e8a7509943d5cd6f851f59923a61a186e80000000000000000000000000000000000000000000000000000000000000060a063498e8db2e75e0a193de89ad2947111d677c9501e75c34a64fcee8fe5a7c7607929fc6bce943d64f1039e1d1f325f02d1e5d71f86ca976c9ab79d19f0fd0e530a5210fbe131087ba1f1b3c92abc4a0dd7c8a47c3c276fac3e09bca964fd74",
                  nonce: 4658,
                  r:
                    105_551_060_165_173_654_536_466_245_809_705_255_348_773_503_447_188_823_324_699_103_004_494_755_354_009,
                  s:
                    6_578_424_718_200_222_268_891_012_570_118_685_130_111_416_504_340_507_122_286_266_818_507_627_932_617,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 28,
                  value: 3_200_000_000_000_000
                }
              ]} = Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
