defmodule EthereumJSONRPC.GethTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.Geth

  @moduletag :no_parity

  describe "fetch_internal_transactions/2" do
    # Infura Mainnet does not support debug_traceTransaction, so this cannot be tested expect in Mox
    setup do
      EthereumJSONRPC.Case.Geth.Mox.setup()
    end

    setup :verify_on_exit!

    # Data taken from Rinkeby
    test "is supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      transaction_index = 13
      transaction_hash = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
      tracer = File.read!("priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js")

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^transaction_hash, %{tracer: ^tracer}]}], _ ->
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
  end

  describe "fetch_pending_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
