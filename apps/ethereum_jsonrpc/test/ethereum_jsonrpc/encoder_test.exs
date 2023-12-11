defmodule EthereumJSONRPC.EncoderTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Encoder

  alias EthereumJSONRPC.Encoder

  describe "encode_function_call/2" do
    test "generates the correct encoding with no arguments" do
      function_selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: []
      }

      assert Encoder.encode_function_call(function_selector, []) == "0x6d4ce63c"
    end

    test "generates the correct encoding with arguments" do
      function_selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.encode_function_call(function_selector, [10]) ==
               "0x9507d39a000000000000000000000000000000000000000000000000000000000000000a"
    end

    test "generates the correct encoding with string argument" do
      function_selector = %ABI.FunctionSelector{
        function: "isNewsletterCoverFullyClaimed",
        input_names: ["newsletterId"],
        inputs_indexed: nil,
        return_names: [""],
        returns: [:bool],
        state_mutability: :view,
        type: :function,
        types: [:string]
      }

      assert Encoder.encode_function_call(function_selector, ["6564f5623e2a9f0001cb7fee"]) ==
               "0xa07a712d000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000183635363466353632336532613966303030316362376665650000000000000000"
    end

    test "generates the correct encoding with string started with 0x" do
      function_selector = %ABI.FunctionSelector{
        function: "isNewsletterCoverFullyClaimed",
        input_names: ["newsletterId"],
        inputs_indexed: nil,
        return_names: [""],
        returns: [:bool],
        state_mutability: :view,
        type: :function,
        types: [:string]
      }

      assert Encoder.encode_function_call(function_selector, ["0x123"]) ==
               "0xa07a712d000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000053078313233000000000000000000000000000000000000000000000000000000"
    end

    test "generates the correct encoding with addresses arguments" do
      function_selector = %ABI.FunctionSelector{
        function: "tokens",
        returns: {:uint, 256},
        types: [:address, :address]
      }

      args = ["0xdab1c67232f92b7707f49c08047b96a4db7a9fc6", "0x6937cb25eb54bc013b9c13c47ab38eb63edd1493"]

      assert Encoder.encode_function_call(function_selector, args) ==
               "0x508493bc000000000000000000000000dab1c67232f92b7707f49c08047b96a4db7a9fc60000000000000000000000006937cb25eb54bc013b9c13c47ab38eb63edd1493"
    end
  end

  describe "decode_result/2" do
    test "correctly decodes the blockchain result" do
      result = %{
        id: "sum",
        jsonrpc: "2.0",
        result: "0x000000000000000000000000000000000000000000000000000000000000002a"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result(result, selector) == {"sum", {:ok, [42]}}
    end

    test "correctly handles the blockchain error response" do
      result = %{
        error: %{
          code: -32602,
          message: "Invalid params: Invalid hex: Invalid character 'x' at position 134."
        },
        id: "sum",
        jsonrpc: "2.0"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result(result, selector) ==
               {"sum", {:error, "(-32602) Invalid params: Invalid hex: Invalid character 'x' at position 134."}}
    end

    test "correctly handles the blockchain error response with returning error as map without data" do
      result = %{
        error: %{
          code: -32602,
          message: "Invalid params: Invalid hex: Invalid character 'x' at position 134."
        },
        id: "sum",
        jsonrpc: "2.0"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result(result, selector, true) ==
               {"sum",
                {:error,
                 %{code: -32602, message: "Invalid params: Invalid hex: Invalid character 'x' at position 134."}}}
    end

    test "correctly handles the blockchain error response with returning error as map with data" do
      result = %{
        error: %{
          code: -32602,
          message: "Invalid params: Invalid hex: Invalid character 'x' at position 134.",
          data: "0x01"
        },
        id: "sum",
        jsonrpc: "2.0"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result(result, selector, true) ==
               {"sum",
                {:error,
                 %{
                   code: -32602,
                   message: "Invalid params: Invalid hex: Invalid character 'x' at position 134.",
                   data: "0x01"
                 }}}
    end

    test "correctly decodes string types" do
      result =
        "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000441494f4e00000000000000000000000000000000000000000000000000000000"

      selector = %ABI.FunctionSelector{function: "name", types: [], returns: [:string]}

      assert Encoder.decode_result(%{id: "storedName", result: result}, selector) == {"storedName", {:ok, ["AION"]}}
    end
  end
end
