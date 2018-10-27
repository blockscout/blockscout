defmodule Explorer.SmartContract.ReaderTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.SmartContract.Reader
  alias Explorer.Chain.Hash

  doctest Explorer.SmartContract.Reader

  setup :verify_on_exit!

  describe "query_contract/4" do
    test "correctly returns the results of the smart contract functions" do
      smart_contract = build(:smart_contract)
      contract_address_hash = Hash.to_string(smart_contract.address_hash)
      abi = smart_contract.abi

      blockchain_get_function_mock()

      response = Reader.query_contract(contract_address_hash, abi, %{"get" => []})

      assert %{"get" => {:ok, [0]}} == response
    end

    test "handles errors when there are malformed function arguments" do
      smart_contract = build(:smart_contract)
      contract_address_hash = Hash.to_string(smart_contract.address_hash)

      int_function_abi = %{
        "constant" => true,
        "inputs" => [
          %{"name" => "a", "type" => "int256"}
        ],
        "name" => "sum",
        "outputs" => [%{"name" => "", "type" => "int256"}],
        "payable" => false,
        "stateMutability" => "pure",
        "type" => "function"
      }

      string_argument = %{"sum" => ["abc"]}

      response = Reader.query_contract(contract_address_hash, [int_function_abi], string_argument)

      assert %{"sum" => {:error, "Data overflow encoding int, data `abc` cannot fit in 256 bits"}} = response
    end

    test "handles standardize errors returned from RPC requests" do
      smart_contract = build(:smart_contract)
      contract_address_hash = Hash.to_string(smart_contract.address_hash)
      abi = smart_contract.abi

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok, [%{id: id, jsonrpc: "2.0", error: %{code: "12345", message: "Error message"}}]}
        end
      )

      response = Reader.query_contract(contract_address_hash, abi, %{"get" => []})

      assert %{"get" => {:error, "(12345) Error message"}} = response
    end

    test "handles bad_gateway errors returned from RPC requests" do
      smart_contract = build(:smart_contract)
      contract_address_hash = Hash.to_string(smart_contract.address_hash)
      abi = smart_contract.abi

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:error, {:bad_gateway, "request_url"}}
        end
      )

      response = Reader.query_contract(contract_address_hash, abi, %{"get" => []})

      assert %{"get" => {:error, "Bad Gateway"}} = response
    end

    test "handles other types of errors" do
      smart_contract = build(:smart_contract)
      contract_address_hash = Hash.to_string(smart_contract.address_hash)
      abi = smart_contract.abi

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
          raise FunctionClauseError
        end
      )

      response = Reader.query_contract(contract_address_hash, abi, %{"get" => []})

      assert %{"get" => {:error, "no function clause matches"}} = response
    end
  end

  describe "query_verified_contract/2" do
    test "correctly returns the results of the smart contract functions" do
      hash =
        :smart_contract
        |> insert()
        |> Map.get(:address_hash)

      blockchain_get_function_mock()

      assert Reader.query_verified_contract(hash, %{"get" => []}) == %{"get" => {:ok, [0]}}
    end
  end

  test "query_unverified_contract/3" do
    address = insert(:address)

    abi = [
      %{
        "constant" => true,
        "inputs" => [],
        "name" => "decimals",
        "outputs" => [
          %{
            "name" => "",
            "type" => "uint8"
          }
        ],
        "payable" => false,
        "type" => "function"
      }
    ]

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000012"}]}
      end
    )

    assert Reader.query_unverified_contract(address.hash, abi, %{"decimals" => []}) == %{"decimals" => {:ok, [18]}}
  end

  describe "setup_call_payload/2" do
    test "returns the expected payload" do
      function_name = "get"
      contract_address = "0x123789abc"
      data = "0x6d4ce63c"

      assert Reader.setup_call_payload(
               {function_name, data},
               contract_address
             ) == %{contract_address: "0x123789abc", data: "0x6d4ce63c", id: "get"}
    end
  end

  describe "read_only_functions/1" do
    test "fetches the smart contract read only functions with the blockchain value" do
      smart_contract =
        insert(
          :smart_contract,
          abi: [
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            },
            %{
              "constant" => true,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "with_arguments",
              "outputs" => [%{"name" => "", "type" => "bool"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ]
        )

      blockchain_get_function_mock()

      response = Reader.read_only_functions(smart_contract.address_hash)

      assert [
               %{
                 "constant" => true,
                 "inputs" => [],
                 "name" => "get",
                 "outputs" => [%{"name" => "", "type" => "uint256", "value" => 0}],
                 "payable" => _,
                 "stateMutability" => _,
                 "type" => _
               },
               %{
                 "constant" => true,
                 "inputs" => [%{"name" => "x", "type" => "uint256"}],
                 "name" => "with_arguments",
                 "outputs" => [%{"name" => "", "type" => "bool", "value" => ""}],
                 "payable" => _,
                 "stateMutability" => _,
                 "type" => _
               }
             ] = response
    end
  end

  describe "query_function/2" do
    test "given the arguments, fetches the function value from the blockchain" do
      smart_contract = insert(:smart_contract)

      blockchain_get_function_mock()

      assert [
               %{
                 "name" => "",
                 "type" => "uint256",
                 "value" => 0
               }
             ] = Reader.query_function(smart_contract.address_hash, %{name: "get", args: []})
    end

    test "nil arguments is treated as []" do
      smart_contract = insert(:smart_contract)

      blockchain_get_function_mock()

      assert [
               %{
                 "name" => "",
                 "type" => "uint256",
                 "value" => 0
               }
             ] = Reader.query_function(smart_contract.address_hash, %{name: "get", args: nil})
    end
  end

  describe "normalize_args/1" do
    test "converts argument when is a number" do
      assert [0] = Reader.normalize_args(["0"])

      assert ["0x798465571ae21a184a272f044f991ad1d5f87a3f"] =
               Reader.normalize_args(["0x798465571ae21a184a272f044f991ad1d5f87a3f"])
    end

    test "converts argument when is a boolean" do
      assert [true] = Reader.normalize_args(["true"])
      assert [false] = Reader.normalize_args(["false"])

      assert ["some string"] = Reader.normalize_args(["some string"])
    end
  end

  describe "link_outputs_and_values/2" do
    test "links the ABI outputs with the values retrieved from the blockchain" do
      blockchain_values = %{
        "getOwner" =>
          {:ok, <<105, 55, 203, 37, 235, 84, 188, 1, 59, 156, 19, 196, 122, 179, 142, 182, 62, 221, 20, 147>>}
      }

      outputs = [%{"name" => "", "type" => "address"}]

      function_name = "getOwner"

      assert [%{"name" => "", "type" => "address", "value" => "0x6937cb25eb54bc013b9c13c47ab38eb63edd1493"}] =
               Reader.link_outputs_and_values(blockchain_values, outputs, function_name)
    end

    test "correctly shows returns of 'bytes' type" do
      blockchain_values = %{
        "get" =>
          {:ok, <<0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
      }

      outputs = [%{"name" => "", "type" => "bytes32"}]

      function_name = "get"

      assert [
               %{
                 "name" => "",
                 "type" => "bytes32",
                 "value" => "0x000a000000000000000000000000000000000000000000000000000000000000"
               }
             ] = Reader.link_outputs_and_values(blockchain_values, outputs, function_name)
    end

    test "links the ABI outputs correctly when there are multiple values" do
      blockchain_values = %{"getNarco" => {:ok, ["Justin Sun", 0, [8, 6, 9, 2, 2, 37]]}}

      outputs = [
        %{"name" => "narcoName", "type" => "string"},
        %{"name" => "weedTotal", "type" => "uint256"},
        %{"name" => "skills", "type" => "uint16[6]"}
      ]

      function_name = "getNarco"

      assert [
               %{
                 "name" => "narcoName",
                 "type" => "string",
                 "value" => "Justin Sun"
               },
               %{"name" => "weedTotal", "type" => "uint256", "value" => 0},
               %{
                 "name" => "skills",
                 "type" => "uint16[6]",
                 "value" => [8, 6, 9, 2, 2, 37]
               }
             ] = Reader.link_outputs_and_values(blockchain_values, outputs, function_name)
    end
  end

  defp blockchain_get_function_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000000"}]}
      end
    )
  end
end
