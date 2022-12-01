defmodule EthereumJSONRPC.Geth.CallTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Geth.Call

  alias EthereumJSONRPC.Geth.Call

  describe "to_internal_transaction_params/1" do
    test "does not fail decoding static_call without output" do
      result =
        Call.to_internal_transaction_params(%{
          "blockNumber" => 584_340,
          "callType" => "staticcall",
          "error" => "execution reverted",
          "from" => "0x3858636f27e269d23db2ef1fcca5f93dcaa564cd",
          "gas" => "0x0",
          "gasUsed" => "0x0",
          "index" => 1,
          "input" =>
            "0x09d10a5e00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000002",
          "to" => "0x79073fc2117dd054fcedacad1e7018c9cbe3ec0b",
          "traceAddress" => [1, 3],
          "transactionHash" => "0xbc38745b826f058ed2f6c93fa5b145323857f06bbb5230b6a6a50e09e0915857",
          "transactionIndex" => 0,
          "type" => "call",
          "value" => "0x0"
        })

      assert result == %{
               block_number: 584_340,
               call_type: "staticcall",
               from_address_hash: "0x3858636f27e269d23db2ef1fcca5f93dcaa564cd",
               gas: 0,
               gas_used: 0,
               index: 1,
               input:
                 "0x09d10a5e00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000002",
               output: nil,
               to_address_hash: "0x79073fc2117dd054fcedacad1e7018c9cbe3ec0b",
               trace_address: [1, 3],
               transaction_hash: "0xbc38745b826f058ed2f6c93fa5b145323857f06bbb5230b6a6a50e09e0915857",
               transaction_index: 0,
               type: "call",
               value: 0,
               error: "execution reverted"
             }
    end
  end
end
