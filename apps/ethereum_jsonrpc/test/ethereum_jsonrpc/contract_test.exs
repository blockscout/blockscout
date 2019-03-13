defmodule EthereumJSONRPC.ContractTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Contract

  import Mox

  alias EthereumJSONRPC.Contract

  describe "execute_contract_functions/3" do
    test "executes the functions with and without the block_number, returns results in order" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

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

      contract_address = "0x0000000000000000000000000000000000000000"

      functions = [
        %{contract_address: contract_address, function_name: "get1", args: []},
        %{contract_address: contract_address, function_name: "get2", args: [], block_number: 1000},
        %{contract_address: contract_address, function_name: "get3", args: []}
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
                 result: "0x0000000000000000000000000000000000000000000000000000000000000020"
               }
           end)
           |> Enum.shuffle()}
        end
      )

      blockchain_result = [
        {:ok, [42]},
        {:ok, [52]},
        {:ok, [32]}
      ]

      assert Contract.execute_contract_functions(
               functions,
               abi,
               json_rpc_named_arguments
             ) == blockchain_result
    end
  end
end
