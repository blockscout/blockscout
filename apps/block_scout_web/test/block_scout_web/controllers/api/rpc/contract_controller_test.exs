defmodule BlockScoutWeb.API.RPC.ContractControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain
  # alias Explorer.{Chain, Factory}

  import Mox

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
               "invalid is not a valid value for `filter`. Please use one of: verified, decompiled, unverified, not_decompiled, 1, 2, 3, 4."

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

      assert response["result"] == [
               %{
                 "ABI" => Jason.encode!(contract.abi),
                 "Address" => to_string(contract.address_hash),
                 "CompilerVersion" => contract.compiler_version,
                 "ContractName" => contract.name,
                 "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
               }
             ]

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

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(address.hash)
               }
             ]

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

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(address.hash)
               }
             ]

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

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(address.hash)
               }
             ]

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

      assert response["result"] == [
               %{
                 "ABI" => Jason.encode!(contract.abi),
                 "Address" => to_string(contract.address_hash),
                 "CompilerVersion" => contract.compiler_version,
                 "ContractName" => contract.name,
                 "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
               }
             ]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only decompiled contracts shows only decompiled contracts", %{params: params, conn: conn} do
      insert(:contract_address)
      decompiled_smart_contract = insert(:decompiled_smart_contract)

      response =
        conn
        |> get("/api", Map.put(params, "filter", "decompiled"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(decompiled_smart_contract.address_hash)
               }
             ]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only decompiled contracts, with a decompiled with version filter", %{params: params, conn: conn} do
      insert(:decompiled_smart_contract, decompiler_version: "foobar")
      smart_contract = insert(:decompiled_smart_contract, decompiler_version: "bizbuz")

      response =
        conn
        |> get("/api", Map.merge(params, %{"filter" => "decompiled", "not_decompiled_with_version" => "foobar"}))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(smart_contract.address_hash)
               }
             ]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only decompiled contracts, with a decompiled with version filter, where another decompiled version exists",
         %{params: params, conn: conn} do
      non_match = insert(:decompiled_smart_contract, decompiler_version: "foobar")
      insert(:decompiled_smart_contract, decompiler_version: "bizbuz", address_hash: non_match.address_hash)
      smart_contract = insert(:decompiled_smart_contract, decompiler_version: "bizbuz")

      response =
        conn
        |> get("/api", Map.merge(params, %{"filter" => "decompiled", "not_decompiled_with_version" => "foobar"}))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert %{
               "ABI" => "Contract source code not verified",
               "Address" => to_string(smart_contract.address_hash)
             } in response["result"]

      refute to_string(non_match.address_hash) in Enum.map(response["result"], &Map.get(&1, "Address"))
      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only not_decompiled (and by extension not verified contracts)", %{params: params, conn: conn} do
      insert(:decompiled_smart_contract)
      insert(:smart_contract, contract_code_md5: "123")
      contract_address = insert(:contract_address)

      response =
        conn
        |> get("/api", Map.put(params, "filter", "not_decompiled"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(contract_address.hash)
               }
             ]

      assert :ok = ExJsonSchema.Validator.validate(listcontracts_schema(), response)
    end

    test "filtering for only not_decompiled (and by extension not verified contracts) does not show empty contracts", %{
      params: params,
      conn: conn
    } do
      insert(:decompiled_smart_contract)
      insert(:smart_contract, contract_code_md5: "123")
      insert(:contract_address, contract_code: "0x")
      contract_address = insert(:contract_address)

      response =
        conn
        |> get("/api", Map.put(params, "filter", "not_decompiled"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(contract_address.hash)
               }
             ]

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
          "Address" => "",
          "SourceCode" => "",
          "ABI" => "Contract source code not verified",
          "ContractName" => "",
          "CompilerVersion" => "",
          "OptimizationUsed" => "",
          "DecompiledSourceCode" => "",
          "DecompilerVersion" => "",
          "ConstructorArguments" => "",
          "EVMVersion" => "",
          "ExternalLibraries" => "",
          "OptimizationRuns" => "",
          "FileName" => "",
          "IsProxy" => "false"
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
          optimization_runs: 200,
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
          "OptimizationRuns" => 200,
          "EVMVersion" => "default",
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      get_implementation()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getsourcecode_schema(), response)
    end

    test "with constructor arguments", %{conn: conn} do
      contract =
        insert(:smart_contract,
          optimization: true,
          optimization_runs: 200,
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
          "OptimizationRuns" => 200,
          "EVMVersion" => "default",
          "ConstructorArguments" =>
            "00000000000000000000000008e7592ce0d7ebabf42844b62ee6a878d4e1913e000000000000000000000000e1b6037da5f1d756499e184ca15254a981c92546",
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      get_implementation()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
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
        optimization_runs: 200,
        evm_version: "default"
      }

      external_libraries = [
        %SmartContract.ExternalLibrary{:address_hash => "0xb18aed9518d735482badb4e8b7fd8d2ba425ce95", :name => "Test"},
        %SmartContract.ExternalLibrary{:address_hash => "0x283539e1b1daf24cdd58a3e934d55062ea663c3f", :name => "Test2"}
      ]

      {:ok, %SmartContract{} = contract} = Chain.create_smart_contract(valid_attrs, external_libraries)

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
          "OptimizationRuns" => 200,
          "EVMVersion" => "default",
          "ExternalLibraries" => [
            %{"name" => "Test", "address_hash" => "0xb18aed9518d735482badb4e8b7fd8d2ba425ce95"},
            %{"name" => "Test2", "address_hash" => "0x283539e1b1daf24cdd58a3e934d55062ea663c3f"}
          ],
          "FileName" => "",
          "IsProxy" => "false"
        }
      ]

      get_implementation()

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
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
        "addressHash" => "0x18d89C12e9463Be6343c35C9990361bA4C42AfC2"
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
          hash: "0x18d89C12e9463Be6343c35C9990361bA4C42AfC2",
          contract_code: smart_contract_bytecode
        )

      params = %{
        "module" => "contract",
        "action" => "verify_via_sourcify",
        "addressHash" => "0x18d89C12e9463Be6343c35C9990361bA4C42AfC2"
      }

      get_implementation()

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

    #   verified_contract = Chain.address_hash_to_smart_contract(contract_address.hash)

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

    #   verified_contract = Chain.address_hash_to_smart_contract(contract_address.hash)

    #   assert result["Address"] == to_string(contract_address.hash)

    #   assert result["SourceCode"] ==
    #            "/**\n* Submitted for verification at blockscout.com on #{verified_contract.inserted_at}\n*/\n" <>
    #              contract_source_code

    #   assert result["ContractName"] == name
    #   assert result["DecompiledSourceCode"] == nil
    #   assert result["DecompilerVersion"] == nil
    #   assert result["OptimizationUsed"] == "true"
    #   assert :ok = ExJsonSchema.Validator.validate(verify_schema(), response)
    # end
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
          "OptimizationUsed" => %{"type" => "string"},
          "DecompiledSourceCode" => %{"type" => "string"},
          "DecompilerVersion" => %{"type" => "string"}
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
  #       "DecompiledSourceCode" => %{"type" => "string"},
  #       "DecompilerVersion" => %{"type" => "string"},
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

  def get_implementation do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
  end
end
