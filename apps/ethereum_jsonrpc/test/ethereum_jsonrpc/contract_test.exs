defmodule EthereumJSONRPC.ContractTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Contract

  import Mox

  setup :verify_on_exit!

  describe "execute_contract_functions/3" do
    test "executes the functions with and without the block_number, returns results in order" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      abi = [
        %{
          "constant" => false,
          "inputs" => [],
          "name" => "get1",
          "method_id" => "054c1a75",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get2",
          "method_id" => "d2178b08",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get3",
          "method_id" => "8321045c",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, method_id: "054c1a75", args: []},
        %{contract_address: contract_address, method_id: "d2178b08", args: [], block_number: 1000},
        %{contract_address: contract_address, method_id: "8321045c", args: []}
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn requests, _options ->
          {:ok,
           requests
           |> Enum.map(fn
             %{id: id, method: "eth_call", params: [%{data: "0x054c1a75", to: ^contract_address}, "latest"]} ->
               %{
                 id: id,
                 result: "0x000000000000000000000000000000000000000000000000000000000000002a"
               }

             %{id: id, method: "eth_call", params: [%{data: "0xd2178b08", to: ^contract_address}, "0x3E8"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000034"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x8321045c", to: ^contract_address}, "latest"]} ->
               %{
                 id: id,
                 error: %{code: -32015, data: "something", message: "Some error"}
               }
           end)
           |> Enum.shuffle()}
        end
      )

      blockchain_result = [
        {:ok, [42]},
        {:ok, [52]},
        {:error, "(-32015) Some error (something)"}
      ]

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               abi,
               json_rpc_named_arguments
             ) == blockchain_result
    end

    test "returns errors if JSONRPC request fails" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      abi = [
        %{
          "constant" => false,
          "inputs" => [],
          "name" => "get",
          "method_id" => "6d4ce63c",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      ]

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, method_id: "6d4ce63c", args: []},
        %{contract_address: contract_address, method_id: "6d4ce63c", args: [], block_number: 1000}
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn _requests, _options ->
          {:error, "Some error"}
        end
      )

      blockchain_result = [
        {:error, "Some error"},
        {:error, "Some error"}
      ]

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               abi,
               json_rpc_named_arguments
             ) == blockchain_result
    end

    test "handles individual request processing errors without affecting other requests" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      abi = [
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get1",
          "method_id" => "054c1a75",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get2",
          "method_id" => "d2178b08",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get3",
          "method_id" => "8321045c",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, method_id: "054c1a75", args: []},
        %{contract_address: contract_address, method_id: "d2178b08", args: []},
        %{contract_address: contract_address, method_id: "8321045c", args: []}
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn requests, _options ->
          {:ok,
           requests
           |> Enum.map(fn
             %{id: id, method: "eth_call", params: [%{data: "0x054c1a75", to: ^contract_address}, "latest"]} ->
               %{
                 id: id,
                 result: "0x000000000000000000000000000000000000000000000000000000000000002a"
               }

             %{id: id, method: "eth_call", params: [%{data: "0xd2178b08", to: ^contract_address}, "latest"]} ->
               # This will cause a decoding error due to invalid hex
               %{
                 id: id,
                 result: "0xINVALID"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x8321045c", to: ^contract_address}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000064"
               }
           end)
           |> Enum.shuffle()}
        end
      )

      results =
        EthereumJSONRPC.execute_contract_functions(
          functions,
          abi,
          json_rpc_named_arguments
        )

      # First request should succeed
      assert {:ok, [42]} = Enum.at(results, 0)

      # Second request should fail with an error (not affecting others)
      assert {:error, _error_message} = Enum.at(results, 1)

      # Third request should succeed
      assert {:ok, [100]} = Enum.at(results, 2)
    end

    test "handles bad_gateway error for entire batch" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      abi = [
        %{
          "constant" => false,
          "inputs" => [],
          "name" => "get",
          "method_id" => "6d4ce63c",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      ]

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, method_id: "6d4ce63c", args: []},
        %{contract_address: contract_address, method_id: "6d4ce63c", args: []}
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn _requests, _options ->
          {:error, {:bad_gateway, "http://localhost:8545"}}
        end
      )

      blockchain_result = [
        {:error, "Bad gateway"},
        {:error, "Bad gateway"}
      ]

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               abi,
               json_rpc_named_arguments
             ) == blockchain_result
    end

    test "handles atom error for entire batch" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      abi = [
        %{
          "constant" => false,
          "inputs" => [],
          "name" => "get",
          "method_id" => "6d4ce63c",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      ]

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, method_id: "6d4ce63c", args: []},
        %{contract_address: contract_address, method_id: "6d4ce63c", args: []}
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn _requests, _options ->
          {:error, :timeout}
        end
      )

      blockchain_result = [
        {:error, "timeout"},
        {:error, "timeout"}
      ]

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               abi,
               json_rpc_named_arguments
             ) == blockchain_result
    end
  end
end
