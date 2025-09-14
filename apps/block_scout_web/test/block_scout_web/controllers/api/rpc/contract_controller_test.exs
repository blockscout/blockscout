defmodule BlockScoutWeb.API.RPC.ContractControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox
  import Ecto.Query

  alias Explorer.{Repo, TestHelper}
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.{Address, SmartContract}

  setup :verify_on_exit!

  if Application.compile_env(:explorer, :chain_type) == :zksync do
    @optimization_runs "0"
  else
    @optimization_runs 200
  end

  def prepare_contracts do
    insert(:contract_address)
    {:ok, dt_1, _} = DateTime.from_iso8601("2022-09-20 10:00:00Z")

    contract_1 =
      insert(:smart_contract,
        contract_code_md5: "123",
        name: "Test 1",
        optimization: "1",
        compiler_version: "v0.6.8+commit.0bbfe453",
        abi: [%{foo: "bar"}],
        inserted_at: dt_1
      )

    insert(:contract_address)
    {:ok, dt_2, _} = DateTime.from_iso8601("2022-09-22 10:00:00Z")

    contract_2 =
      insert(:smart_contract,
        contract_code_md5: "12345",
        name: "Test 2",
        optimization: "0",
        compiler_version: "v0.7.5+commit.eb77ed08",
        abi: [%{foo: "bar-2"}],
        inserted_at: dt_2
      )

    insert(:contract_address)
    {:ok, dt_3, _} = DateTime.from_iso8601("2022-09-24 10:00:00Z")

    contract_3 =
      insert(:smart_contract,
        contract_code_md5: "1234567",
        name: "Test 3",
        optimization: "1",
        compiler_version: "v0.4.26+commit.4563c3fc",
        abi: [%{foo: "bar-3"}],
        inserted_at: dt_3
      )

    [contract_1, contract_2, contract_3]
  end

  def result(contract) do
    %{
      "ABI" => Jason.encode!(contract.abi),
      "Address" => to_string(contract.address_hash),
      "CompilerVersion" => contract.compiler_version,
      "ContractName" => contract.name,
      "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
    }
  end

  defp result_not_verified(address_hash) do
    %{
      "ABI" => "Contract source code not verified",
      "Address" => to_string(address_hash)
    }
  end

  setup do
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)
  end

  describe "listcontracts" do
    setup do
      %{params: %{"module" => "contract", "action" => "listcontracts"}}
    end

    test "with an invalid filter value", %{conn: conn, params: params} do
      response =
        conn
        |> get("/api", Map.put(params, "filter", "invalid"))
        |> json_response(400)

      assert response["message"] ==
               "invalid is not a valid value for `filter`. Please use one of: verified, unverified, 1, 2."

      assert response["status"] == "0"
      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "with no contracts", %{conn: conn, params: params} do
      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"
      assert response["result"] == []
      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "with a verified smart contract, all contract information is shown", %{conn: conn, params: params} do
      contract = insert(:smart_contract, contract_code_md5: "123")

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      result_props = result(contract) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == result(contract)[prop]
      end

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "with an unverified contract address, only basic information is shown", %{conn: conn, params: params} do
      address = insert(:contract_address)

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [result_not_verified(address.hash)]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only unverified contracts shows only unverified contracts", %{params: params, conn: conn} do
      address = insert(:contract_address)
      insert(:smart_contract, contract_code_md5: "123")

      response =
        conn
        |> get("/api", Map.put(params, "filter", "unverified"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [result_not_verified(address.hash)]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only unverified contracts does not show self destructed contracts", %{
      params: params,
      conn: conn
    } do
      address = insert(:contract_address)
      insert(:smart_contract, contract_code_md5: "123")
      insert(:contract_address, contract_code: "0x")

      response =
        conn
        |> get("/api", Map.put(params, "filter", "unverified"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [result_not_verified(address.hash)]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only verified contracts shows only verified contracts", %{params: params, conn: conn} do
      insert(:contract_address)
      contract = insert(:smart_contract, contract_code_md5: "123")

      response =
        conn
        |> get("/api", Map.put(params, "filter", "verified"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      result_props = result(contract) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == result(contract)[prop]
      end

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only verified contracts in the date range shows only verified contracts in that range", %{
      params: params,
      conn: conn
    } do
      [_contract_1, contract_2, _contract_3] = prepare_contracts()

      filter_params =
        params
        |> Map.put("filter", "verified")
        |> Map.put("verified_at_start_timestamp", "1663749418")
        |> Map.put("verified_at_end_timestamp", "1663922218")

      response =
        conn
        |> get("/api", filter_params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      result_props = result(contract_2) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == result(contract_2)[prop]
      end

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only verified contracts with start created_at timestamp >= given timestamp shows only verified contracts in that range",
         %{
           params: params,
           conn: conn
         } do
      [_contract_1, contract_2, contract_3] = prepare_contracts()

      filter_params =
        params
        |> Map.put("filter", "verified")
        |> Map.put("verified_at_start_timestamp", "1663749418")

      response =
        conn
        |> get("/api", filter_params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      result_props = result(contract_2) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == result(contract_2)[prop]
        assert Enum.at(response["result"], 1)[prop] == result(contract_3)[prop]
      end

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only verified contracts with end created_at timestamp < given timestamp shows only verified contracts in that range",
         %{
           params: params,
           conn: conn
         } do
      [contract_1, contract_2, _contract_3] = prepare_contracts()

      filter_params =
        params
        |> Map.put("filter", "verified")
        |> Map.put("verified_at_end_timestamp", "1663922218")

      response =
        conn
        |> get("/api", filter_params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      result_props = result(contract_1) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == result(contract_1)[prop]
        assert Enum.at(response["result"], 1)[prop] == result(contract_2)[prop]
      end

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end
  end

  describe "getabi" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getabi"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getabi_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getabi",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getabi_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getabi",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == nil
      assert response["status"] == "0"
      assert response["message"] == "Contract source code not verified"
      assert :ok = ExJsonSchema.Validator.validate(getabi_schema(), response)
    end

    test "with a verified contract address", %{conn: conn} do
      contract = insert(:smart_contract, contract_code_md5: "123")

      params = %{
        "module" => "contract",
        "action" => "getabi",
        "address" => to_string(contract.address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == Jason.encode!(contract.abi)
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getabi_schema(), response)
    end
  end

  describe "getsourcecode" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getsourcecode"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      expected_result = [
        %{
          "Address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with a verified contract address", %{conn: conn} do
      contract =
        insert(:smart_contract,
          optimization: true,
          optimization_runs: @optimization_runs,
          evm_version: "default",
          contract_code_md5: "123"
        )

      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => to_string(contract.address_hash)
      }

      expected_result = [
        %{
          "Address" => to_string(contract.address_hash),
          "SourceCode" => contract.contract_source_code,
          "ABI" => Jason.encode!(contract.abi),
          "ContractName" => contract.name,
          "CompilerVersion" => contract.compiler_version,
          # The contract's optimization value is true, so the expected value
          # for `OptimizationUsed` is "1". If it was false, the expected value
          # would be "0".
          "OptimizationUsed" => "true",
          "OptimizationRuns" => @optimization_runs,
          "EVMVersion" => "default",
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      TestHelper.get_all_proxies_implementation_zero_addresses()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      result_props = Enum.at(expected_result, 0) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == Enum.at(expected_result, 0)[prop]
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with a verified proxy contract address", %{conn: conn} do
      implementation_contract =
        insert(:smart_contract,
          name: "Implementation",
          external_libraries: [],
          constructor_arguments: "",
          abi: [
            %{
              "type" => "constructor",
              "inputs" => [
                %{"type" => "address", "name" => "_proxyStorage"},
                %{"type" => "address", "name" => "_implementationAddress"}
              ]
            },
            %{
              "constant" => false,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            },
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ],
          license_type: 9
        )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract.address_hash.bytes, case: :lower)

      proxy_transaction_input =
        "0x11b804ab000000000000000000000000" <>
          implementation_contract_address_hash_string <>
          "000000000000000000000000000000000000000000000000000000000000006035323031313537360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000284e159163400000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd30000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d61100000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d6110000000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd300000000000000000000000000000000000000000000000000000000000000184f7074696d69736d2053756273637269626572204e465473000000000000000000000000000000000000000000000000000000000000000000000000000000054f504e46540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000037697066733a2f2f516d66544e504839765651334b5952346d6b52325a6b757756424266456f5a5554545064395538666931503332752f300000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c82bbe41f2cf04e3a8efa18f7032bdd7f6d98a81000000000000000000000000efba8a2a82ec1fb1273806174f5e28fbb917cf9500000000000000000000000000000000000000000000000000000000"

      proxy_deployed_bytecode =
        "0x363d3d373d3d3d363d73" <> implementation_contract_address_hash_string <> "5af43d82803e903d91602b57fd5bf3"

      proxy_address =
        insert(:contract_address,
          contract_code: proxy_deployed_bytecode,
          verified: true
        )

      proxy_abi = [
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "payable" => false,
          "outputs" => [%{"type" => "bool", "name" => ""}],
          "name" => "upgradeTo",
          "inputs" => [%{"type" => "address", "name" => "newImplementation"}],
          "constant" => false
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "payable" => false,
          "outputs" => [%{"type" => "uint256", "name" => ""}],
          "name" => "version",
          "inputs" => [],
          "constant" => true
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "payable" => false,
          "outputs" => [%{"type" => "address", "name" => ""}],
          "name" => "implementation",
          "inputs" => [],
          "constant" => true
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "payable" => false,
          "outputs" => [],
          "name" => "renounceOwnership",
          "inputs" => [],
          "constant" => false
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "payable" => false,
          "outputs" => [%{"type" => "address", "name" => ""}],
          "name" => "getOwner",
          "inputs" => [],
          "constant" => true
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "payable" => false,
          "outputs" => [%{"type" => "address", "name" => ""}],
          "name" => "getProxyStorage",
          "inputs" => [],
          "constant" => true
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "payable" => false,
          "outputs" => [],
          "name" => "transferOwnership",
          "inputs" => [%{"type" => "address", "name" => "_newOwner"}],
          "constant" => false
        },
        %{
          "type" => "constructor",
          "stateMutability" => "nonpayable",
          "payable" => false,
          "inputs" => [
            %{"type" => "address", "name" => "_proxyStorage"},
            %{"type" => "address", "name" => "_implementationAddress"}
          ]
        },
        %{"type" => "fallback", "stateMutability" => "nonpayable", "payable" => false},
        %{
          "type" => "event",
          "name" => "Upgraded",
          "inputs" => [
            %{"type" => "uint256", "name" => "version", "indexed" => false},
            %{"type" => "address", "name" => "implementation", "indexed" => true}
          ],
          "anonymous" => false
        },
        %{
          "type" => "event",
          "name" => "OwnershipRenounced",
          "inputs" => [%{"type" => "address", "name" => "previousOwner", "indexed" => true}],
          "anonymous" => false
        },
        %{
          "type" => "event",
          "name" => "OwnershipTransferred",
          "inputs" => [
            %{"type" => "address", "name" => "previousOwner", "indexed" => true},
            %{"type" => "address", "name" => "newOwner", "indexed" => true}
          ],
          "anonymous" => false
        }
      ]

      proxy_contract =
        insert(:smart_contract,
          address_hash: proxy_address.hash,
          name: "Proxy",
          abi: proxy_abi
        )

      insert(:transaction,
        created_contract_address_hash: proxy_address.hash,
        input: proxy_transaction_input
      )
      |> with_block(status: :ok)

      name = implementation_contract.name

      insert(:proxy_implementation,
        proxy_address_hash: proxy_address.hash,
        proxy_type: "eip1167",
        address_hashes: [implementation_contract.address_hash],
        names: [name]
      )

      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => Address.checksum(proxy_address.hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      expected_result = [
        %{
          "Address" => to_string(proxy_contract.address_hash),
          "SourceCode" => proxy_contract.contract_source_code,
          "ABI" => Jason.encode!(proxy_contract.abi),
          "ContractName" => proxy_contract.name,
          "CompilerVersion" => proxy_contract.compiler_version,
          "FileName" => "",
          "IsProxy" => "true",
          "ImplementationAddress" => to_string(implementation_contract.address_hash),
          "ImplementationAddresses" => [to_string(implementation_contract.address_hash)],
          "EVMVersion" => nil,
          "OptimizationUsed" => "false"
        }
      ]

      result_props = Enum.at(expected_result, 0) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == Enum.at(expected_result, 0)[prop]
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with constructor arguments", %{conn: conn} do
      contract =
        insert(:smart_contract,
          optimization: true,
          optimization_runs: @optimization_runs,
          evm_version: "default",
          constructor_arguments:
            "00000000000000000000000008e7592ce0d7ebabf42844b62ee6a878d4e1913e000000000000000000000000e1b6037da5f1d756499e184ca15254a981c92546",
          contract_code_md5: "123"
        )

      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => to_string(contract.address_hash)
      }

      expected_result = [
        %{
          "Address" => to_string(contract.address_hash),
          "SourceCode" => contract.contract_source_code,
          "ABI" => Jason.encode!(contract.abi),
          "ContractName" => contract.name,
          "CompilerVersion" => contract.compiler_version,
          "OptimizationUsed" => "true",
          "OptimizationRuns" => @optimization_runs,
          "EVMVersion" => "default",
          "ConstructorArguments" =>
            "00000000000000000000000008e7592ce0d7ebabf42844b62ee6a878d4e1913e000000000000000000000000e1b6037da5f1d756499e184ca15254a981c92546",
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      TestHelper.get_all_proxies_implementation_zero_addresses()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      result_props = Enum.at(expected_result, 0) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == Enum.at(expected_result, 0)[prop]
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with external library", %{conn: conn} do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "Test",
        compiler_version: "0.4.23",
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [
          %{
            "constant" => false,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "set",
            "outputs" => [],
            "payable" => false,
            "stateMutability" => "nonpayable",
            "type" => "function"
          },
          %{
            "constant" => true,
            "inputs" => [],
            "name" => "get",
            "outputs" => [%{"name" => "", "type" => "uint256"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ],
        optimization: true,
        optimization_runs: @optimization_runs,
        evm_version: "default"
      }

      external_libraries = [
        %SmartContract.ExternalLibrary{:address_hash => "0xb18aed9518d735482badb4e8b7fd8d2ba425ce95", :name => "Test"},
        %SmartContract.ExternalLibrary{:address_hash => "0x283539e1b1daf24cdd58a3e934d55062ea663c3f", :name => "Test2"}
      ]

      {:ok, %SmartContract{} = contract} = SmartContract.create_smart_contract(valid_attrs, external_libraries)

      params = %{
        "module" => "contract",
        "action" => "getsourcecode",
        "address" => to_string(contract.address_hash)
      }

      expected_result = [
        %{
          "Address" => to_string(contract.address_hash),
          "SourceCode" => contract.contract_source_code,
          "ABI" => Jason.encode!(contract.abi),
          "ContractName" => contract.name,
          "CompilerVersion" => contract.compiler_version,
          "OptimizationUsed" => "true",
          "OptimizationRuns" => @optimization_runs,
          "EVMVersion" => "default",
          "ExternalLibraries" => [
            %{"name" => "Test", "address_hash" => "0xb18aed9518d735482badb4e8b7fd8d2ba425ce95"},
            %{"name" => "Test2", "address_hash" => "0x283539e1b1daf24cdd58a3e934d55062ea663c3f"}
          ],
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      TestHelper.get_all_proxies_implementation_zero_addresses()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      result_props = Enum.at(expected_result, 0) |> Map.keys()

      for prop <- result_props do
        assert Enum.at(response["result"], 0)[prop] == Enum.at(expected_result, 0)[prop]
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end
  end

  describe "verify" do
    test "verify known on sourcify repo contract", %{conn: conn} do
      response = verify(conn)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"]["ABI"] ==
               "[{\"inputs\":[],\"name\":\"retrieve\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_number\",\"type\":\"uint256\"}],\"name\":\"store\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]"

      assert response["result"]["CompilerVersion"] == "v0.7.6+commit.7338295f"
      assert response["result"]["ContractName"] == "Storage"
      assert response["result"]["EVMVersion"] == "istanbul"
      assert response["result"]["OptimizationUsed"] == "false"
    end

    test "verify already verified contract", %{conn: conn} do
      _response = verify(conn)

      params = %{
        "module" => "contract",
        "action" => "verify_via_sourcify",
        "addressHash" => "0xf26594F585De4EB0Ae9De865d9053FEe02ac6eF1"
      }

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] == "Smart-contract already verified."
      assert response["status"] == "0"
      assert response["result"] == nil
    end

    defp verify(conn) do
      smart_contract_bytecode =
        "0x6080604052348015600f57600080fd5b506004361060325760003560e01c80632e64cec11460375780636057361d146053575b600080fd5b603d607e565b6040518082815260200191505060405180910390f35b607c60048036036020811015606757600080fd5b81019080803590602001909291905050506087565b005b60008054905090565b806000819055505056fea26469706673582212205afbc4864a2486ec80f10e5eceeaac30e88c9b3dfcd1bfadd6cdf6e6cb6e1fd364736f6c63430007060033"

      _created_contract_address =
        insert(
          :address,
          hash: "0xf26594F585De4EB0Ae9De865d9053FEe02ac6eF1",
          contract_code: smart_contract_bytecode
        )

      params = %{
        "module" => "contract",
        "action" => "verify_via_sourcify",
        "addressHash" => "0xf26594F585De4EB0Ae9De865d9053FEe02ac6eF1"
      }

      TestHelper.get_all_proxies_implementation_zero_addresses()

      conn
      |> get("/api", params)
      |> json_response(200)
    end

    # flaky test
    # test "with an address that doesn't exist", %{conn: conn} do
    #   contract_code_info = Factory.contract_code_info()

    #   contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)
    #   insert(:transaction, created_contract_address_hash: contract_address.hash, input: contract_code_info.tx_input)

    #   params = %{
    #     "module" => "contract",
    #     "action" => "verify",
    #     "addressHash" => to_string(contract_address.hash),
    #     "name" => contract_code_info.name,
    #     "compilerVersion" => contract_code_info.version,
    #     "optimization" => contract_code_info.optimized,
    #     "contractSourceCode" => contract_code_info.source_code
    #   }

    #   response =
    #     conn
    #     |> get("/api", params)
    #     |> json_response(200)

    #   verified_contract = SmartContract.address_hash_to_smart_contract(contract_address.hash)

    #   expected_result = %{
    #     "Address" => to_string(contract_address.hash),
    #     "SourceCode" =>
    #       "/**\n* Submitted for verification at blockscout.com on #{verified_contract.inserted_at}\n*/\n" <>
    #         contract_code_info.source_code,
    #     "ABI" => Jason.encode!(contract_code_info.abi),
    #     "ContractName" => contract_code_info.name,
    #     "CompilerVersion" => contract_code_info.version,
    #     "OptimizationUsed" => "false",
    #     "EVMVersion" => nil
    #   }

    #   assert response["status"] == "1"
    #   assert response["result"] == expected_result
    #   assert response["message"] == "OK"
    #   assert :ok = ExJsonSchema.Validator.validate(verify_schema(), response)
    # end

    # flaky test
    # test "with external libraries", %{conn: conn} do
    #   contract_data =
    #     "#{File.cwd!()}/test/support/fixture/smart_contract/contract_with_lib.json"
    #     |> File.read!()
    #     |> Jason.decode!()
    #     |> List.first()

    #   %{
    #     "compiler_version" => compiler_version,
    #     "external_libraries" => external_libraries,
    #     "name" => name,
    #     "optimize" => optimize,
    #     "contract" => contract_source_code,
    #     "expected_bytecode" => expected_bytecode,
    #     "tx_input" => tx_input
    #   } = contract_data

    #   contract_address = insert(:contract_address, contract_code: "0x" <> expected_bytecode)
    #   insert(:transaction, created_contract_address_hash: contract_address.hash, input: "0x" <> tx_input)

    #   params = %{
    #     "module" => "contract",
    #     "action" => "verify",
    #     "addressHash" => to_string(contract_address.hash),
    #     "name" => name,
    #     "compilerVersion" => compiler_version,
    #     "optimization" => optimize,
    #     "contractSourceCode" => contract_source_code
    #   }

    #   params_with_external_libraries =
    #     external_libraries
    #     |> Enum.with_index()
    #     |> Enum.reduce(params, fn {{name, address}, index}, acc ->
    #       name_key = "library#{index + 1}Name"
    #       address_key = "library#{index + 1}Address"

    #       acc
    #       |> Map.put(name_key, name)
    #       |> Map.put(address_key, address)
    #     end)

    #   response =
    #     conn
    #     |> get("/api", params_with_external_libraries)
    #     |> json_response(200)

    #   assert response["status"] == "1"
    #   assert response["message"] == "OK"

    #   result = response["result"]

    #   verified_contract = SmartContract.address_hash_to_smart_contract(contract_address.hash)

    #   assert result["Address"] == to_string(contract_address.hash)

    #   assert result["SourceCode"] ==
    #            "/**\n* Submitted for verification at blockscout.com on #{verified_contract.inserted_at}\n*/\n" <>
    #              contract_source_code

    #   assert result["ContractName"] == name
    #   assert result["OptimizationUsed"] == "true"
    #   assert :ok = ExJsonSchema.Validator.validate(verify_schema(), response)
    # end
  end

  describe "getcontractcreation" do
    setup do
      %{params: %{"module" => "contract", "action" => "getcontractcreation"}}
    end

    test "return error", %{conn: conn, params: params} do
      %{
        "status" => "0",
        "message" => "Query parameter contractaddresses is required",
        "result" => "Query parameter contractaddresses is required"
      } =
        conn
        |> get("/api", params)
        |> json_response(200)
    end

    test "get empty list", %{conn: conn, params: params} do
      address = build(:address)
      address_1 = insert(:address)

      %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      } =
        conn
        |> get("/api", Map.put(params, "contractaddresses", "#{to_string(address)},#{to_string(address_1)}"))
        |> json_response(200)
    end

    test "get contract creation info from a transaction", %{conn: conn, params: params} do
      address_1 = build(:address)
      address = insert(:contract_address)
      {:ok, block_timestamp, _} = DateTime.from_iso8601("2021-05-05T21:42:11.000000Z")
      unix_timestamp = DateTime.to_unix(block_timestamp, :second)

      transaction =
        insert(:transaction,
          created_contract_address: address,
          block_timestamp: block_timestamp
        )

      %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "contractAddress" => contract_address,
            "contractCreator" => contract_creator,
            "txHash" => transaction_hash,
            "blockNumber" => block_number,
            "timestamp" => timestamp,
            "contractFactory" => "",
            "creationBytecode" => creation_bytecode
          }
        ]
      } =
        conn
        |> get("/api", Map.put(params, "contractaddresses", "#{to_string(address)},#{to_string(address_1)}"))
        |> json_response(200)

      assert contract_address == to_string(address.hash)
      assert contract_creator == to_string(transaction.from_address_hash)
      assert transaction_hash == to_string(transaction.hash)
      assert block_number == to_string(transaction.block_number)
      assert timestamp == to_string(unix_timestamp)
      assert creation_bytecode == to_string(transaction.input)
    end

    test "get contract creation info via internal transaction", %{conn: conn, params: params} do
      {:ok, block_timestamp, _} = DateTime.from_iso8601("2021-05-05T21:42:11.000000Z")
      unix_timestamp = DateTime.to_unix(block_timestamp, :second)

      block = insert(:block, timestamp: block_timestamp)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      internal_transaction =
        insert(:internal_transaction_create,
          transaction: transaction,
          index: 1,
          block_hash: transaction.block_hash,
          block_index: transaction.index
        )

      address = internal_transaction.created_contract_address

      %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "contractAddress" => contract_address,
            "contractCreator" => contract_creator,
            "txHash" => transaction_hash,
            "blockNumber" => block_number,
            "timestamp" => timestamp,
            "contractFactory" => contract_factory,
            "creationBytecode" => creation_bytecode
          }
        ]
      } =
        conn
        |> get("/api", Map.put(params, "contractaddresses", to_string(address)))
        |> json_response(200)

      assert contract_address == to_string(internal_transaction.created_contract_address_hash)
      assert contract_creator == to_string(internal_transaction.transaction.from_address_hash)
      assert transaction_hash == to_string(internal_transaction.transaction.hash)
      assert block_number == to_string(internal_transaction.transaction.block_number)
      assert timestamp == to_string(unix_timestamp)
      assert contract_factory == to_string(internal_transaction.from_address_hash)
      assert creation_bytecode == to_string(internal_transaction.init)
    end

    test "get contract creation info via internal transaction with index 0 and parent transaction - contractFactory should be empty",
         %{
           conn: conn,
           params: params
         } do
      {:ok, block_timestamp, _} = DateTime.from_iso8601("2021-05-05T21:42:11.000000Z")
      block = insert(:block, timestamp: block_timestamp)
      contract_address = insert(:contract_address)

      # Create a transaction that creates the contract
      transaction =
        :transaction
        |> insert(created_contract_address: contract_address)
        |> with_block(block)

      # Also create an internal transaction with index 0 for the same contract
      insert(:internal_transaction_create,
        transaction: transaction,
        # index 0 should result in empty contractFactory
        index: 0,
        created_contract_address: contract_address,
        block_hash: transaction.block_hash,
        block_index: transaction.index
      )

      assert %{
               "result" => [
                 %{
                   "contractFactory" => "",
                   "contractCreator" => contract_creator
                 }
               ]
             } =
               conn
               |> get("/api", Map.put(params, "contractaddresses", to_string(contract_address)))
               |> json_response(200)

      assert contract_creator == to_string(transaction.from_address_hash)
    end
  end

  describe "verifyproxycontract & checkproxyverification" do
    setup do
      %{params: %{"module" => "contract"}}
    end

    @proxy_abi [
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [%{"type" => "bool", "name" => ""}],
        "name" => "upgradeTo",
        "inputs" => [%{"type" => "address", "name" => "newImplementation"}],
        "constant" => false
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "uint256", "name" => ""}],
        "name" => "version",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "implementation",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "renounceOwnership",
        "inputs" => [],
        "constant" => false
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "getOwner",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "getProxyStorage",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferOwnership",
        "inputs" => [%{"type" => "address", "name" => "_newOwner"}],
        "constant" => false
      },
      %{
        "type" => "constructor",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "inputs" => [
          %{"type" => "address", "name" => "_proxyStorage"},
          %{"type" => "address", "name" => "_implementationAddress"}
        ]
      },
      %{"type" => "fallback", "stateMutability" => "nonpayable", "payable" => false},
      %{
        "type" => "event",
        "name" => "Upgraded",
        "inputs" => [
          %{"type" => "uint256", "name" => "version", "indexed" => false},
          %{"type" => "address", "name" => "implementation", "indexed" => true}
        ],
        "anonymous" => false
      },
      %{
        "type" => "event",
        "name" => "OwnershipRenounced",
        "inputs" => [%{"type" => "address", "name" => "previousOwner", "indexed" => true}],
        "anonymous" => false
      },
      %{
        "type" => "event",
        "name" => "OwnershipTransferred",
        "inputs" => [
          %{"type" => "address", "name" => "previousOwner", "indexed" => true},
          %{"type" => "address", "name" => "newOwner", "indexed" => true}
        ],
        "anonymous" => false
      }
    ]
    @implementation_abi [
      %{
        "constant" => false,
        "inputs" => [%{"name" => "x", "type" => "uint256"}],
        "name" => "set",
        "outputs" => [],
        "payable" => false,
        "stateMutability" => "nonpayable",
        "type" => "function"
      },
      %{
        "constant" => true,
        "inputs" => [],
        "name" => "get",
        "outputs" => [%{"name" => "", "type" => "uint256"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    ]
    test "verify", %{conn: conn, params: params} do
      proxy_contract_address = insert(:contract_address)

      insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      implementation_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: implementation_contract_address.hash,
        abi: @implementation_abi,
        contract_code_md5: "123"
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

      TestHelper.get_all_proxies_implementation_zero_addresses()

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000" <> implementation_contract_address_hash_string
             }
           ]}
        end
      )

      %{
        "message" => "OK",
        "result" => uid,
        "status" => "1"
      } =
        conn
        |> get(
          "/api",
          Map.merge(params, %{"action" => "verifyproxycontract", "address" => to_string(proxy_contract_address.hash)})
        )
        |> json_response(200)

      :timer.sleep(333)

      result =
        "The proxy's (#{to_string(proxy_contract_address.hash)}) implementation contract is found at #{to_string(implementation_contract_address.hash)} and is successfully updated."

      %{
        "message" => "OK",
        "result" => ^result,
        "status" => "1"
      } =
        conn
        |> get("/api", Map.merge(params, %{"action" => "checkproxyverification", "guid" => uid}))
        |> json_response(200)

      assert %Implementation{address_hashes: implementations} =
               Implementation
               |> where([i], i.proxy_address_hash == ^proxy_contract_address.hash)
               |> Repo.one()

      assert implementations == [implementation_contract_address.hash]
    end
  end

  defp listcontracts_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "Address" => %{"type" => "string"},
          "ABI" => %{"type" => "string"},
          "ContractName" => %{"type" => "string"},
          "CompilerVersion" => %{"type" => "string"},
          "OptimizationUsed" => %{"type" => "string"}
        }
      }
    })
  end

  defp getabi_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp getsourcecode_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "Address" => %{"type" => "string"},
          "SourceCode" => %{"type" => "string"},
          "ABI" => %{"type" => "string"},
          "ContractName" => %{"type" => "string"},
          "CompilerVersion" => %{"type" => "string"},
          "OptimizationUsed" => %{"type" => "string"}
        }
      }
    })
  end

  # defp verify_schema do
  #   resolve_schema(%{
  #     "type" => "object",
  #     "properties" => %{
  #       "Address" => %{"type" => "string"},
  #       "SourceCode" => %{"type" => "string"},
  #       "ABI" => %{"type" => "string"},
  #       "ContractName" => %{"type" => "string"},
  #       "CompilerVersion" => %{"type" => "string"},
  #       "OptimizationUsed" => %{"type" => "string"}
  #     }
  #   })
  # end

  defp resolve_schema(result) do
    %{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"}
      }
    }
    |> put_in(["properties", "result"], result)
    |> ExJsonSchema.Schema.resolve()
  end
end
