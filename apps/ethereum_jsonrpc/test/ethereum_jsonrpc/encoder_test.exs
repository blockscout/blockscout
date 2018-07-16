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

      assert Encoder.encode_function_call({function_selector, []}) == {"get", "0x6d4ce63c"}
    end

    test "generates the correct encoding with arguments" do
      function_selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.encode_function_call({function_selector, [10]}) ==
               {"get", "0x9507d39a000000000000000000000000000000000000000000000000000000000000000a"}
    end

    test "generates the correct encoding with addresses arguments" do
      function_selector = %ABI.FunctionSelector{
        function: "tokens",
        returns: {:uint, 256},
        types: [:address, :address]
      }

      args = ["0xdab1c67232f92b7707f49c08047b96a4db7a9fc6", "0x6937cb25eb54bc013b9c13c47ab38eb63edd1493"]

      assert Encoder.encode_function_call({function_selector, args}) ==
               {"tokens",
                "0x508493bc000000000000000000000000dab1c67232f92b7707f49c08047b96a4db7a9fc60000000000000000000000006937cb25eb54bc013b9c13c47ab38eb63edd1493"}
    end
  end

  describe "get_selectors/2" do
    test "return the selectors of the desired functions with their arguments" do
      abi = [
        %ABI.FunctionSelector{
          function: "fn1",
          returns: {:uint, 256},
          types: [uint: 256]
        },
        %ABI.FunctionSelector{
          function: "fn2",
          returns: {:uint, 256},
          types: [uint: 256]
        }
      ]

      fn1 = %ABI.FunctionSelector{
        function: "fn1",
        returns: {:uint, 256},
        types: [uint: 256]
      }

      assert Encoder.get_selectors(abi, %{"fn1" => [10]}) == [{fn1, [10]}]
    end
  end

  describe "get_selector_from_name/2" do
    test "return the selector of the desired function" do
      abi = [
        %ABI.FunctionSelector{
          function: "fn1",
          returns: {:uint, 256},
          types: [uint: 256]
        },
        %ABI.FunctionSelector{
          function: "fn2",
          returns: {:uint, 256},
          types: [uint: 256]
        }
      ]

      fn1 = %ABI.FunctionSelector{
        function: "fn1",
        returns: {:uint, 256},
        types: [uint: 256]
      }

      assert Encoder.get_selector_from_name(abi, "fn1") == fn1
    end
  end

  describe "decode_results/3" do
    test "separates the selectors and map the results" do
      result =
        {:ok,
         [
           %{
             "id" => "get1",
             "jsonrpc" => "2.0",
             "result" => "0x000000000000000000000000000000000000000000000000000000000000002a"
           },
           %{
             "id" => "get2",
             "jsonrpc" => "2.0",
             "result" => "0x000000000000000000000000000000000000000000000000000000000000002a"
           },
           %{
             "id" => "get3",
             "jsonrpc" => "2.0",
             "result" => "0x0000000000000000000000000000000000000000000000000000000000000020"
           }
         ]}

      abi = [
        %{
          "constant" => false,
          "inputs" => [],
          "name" => "get1",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get2",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get3",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      functions = %{
        "get1" => [],
        "get2" => [],
        "get3" => []
      }

      assert Encoder.decode_abi_results(result, abi, functions) == %{
               "get1" => [42],
               "get2" => [42],
               "get3" => [32]
             }
    end
  end

  describe "decode_result/1" do
    test "correclty decodes the blockchain result" do
      result = %{
        "id" => "sum",
        "jsonrpc" => "2.0",
        "result" => "0x000000000000000000000000000000000000000000000000000000000000002a"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result({result, selector}) == {"sum", [42]}
    end

    test "correclty handles the blockchain error response" do
      result = %{
        "error" => %{
          "code" => -32602,
          "message" => "Invalid params: Invalid hex: Invalid character 'x' at position 134."
        },
        "id" => "sum",
        "jsonrpc" => "2.0"
      }

      selector = %ABI.FunctionSelector{
        function: "get",
        returns: {:uint, 256},
        types: [{:uint, 256}]
      }

      assert Encoder.decode_result({result, selector}) ==
               {"sum", ["-32602 => Invalid params: Invalid hex: Invalid character 'x' at position 134."]}
    end

    test "correclty decodes string types" do
      result =
        "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000441494f4e00000000000000000000000000000000000000000000000000000000"

      selector = %ABI.FunctionSelector{function: "name", types: [], returns: :string}

      assert Encoder.decode_result({%{"id" => "storedName", "result" => result}, selector}) ==
               {"storedName", [["AION"]]}
    end
  end
end
