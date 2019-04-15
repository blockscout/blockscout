defmodule BlockScoutWeb.API.RPC.ContractControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Factory

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
    end

    test "with no contracts", %{conn: conn, params: params} do
      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"
      assert response["result"] == []
    end

    test "with a verified smart contract, all contract information is shown", %{conn: conn, params: params} do
      contract = insert(:smart_contract)

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
                 "DecompiledSourceCode" => "Contract source code not decompiled.",
                 "DecompilerVersion" => "",
                 "OptimizationUsed" => if(contract.optimization, do: "1", else: "0"),
                 "SourceCode" => contract.contract_source_code
               }
             ]
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
                 "Address" => to_string(address.hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => "Contract source code not decompiled.",
                 "DecompilerVersion" => "",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
    end

    test "filtering for only unverified contracts shows only unverified contracts", %{params: params, conn: conn} do
      address = insert(:contract_address)
      insert(:smart_contract)

      response =
        conn
        |> get("/api", Map.put(params, "filter", "unverified"))
        |> json_response(200)

      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(address.hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => "Contract source code not decompiled.",
                 "DecompilerVersion" => "",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
    end

    test "filtering for only verified contracts shows only verified contracts", %{params: params, conn: conn} do
      insert(:contract_address)
      contract = insert(:smart_contract)

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
                 "DecompiledSourceCode" => "Contract source code not decompiled.",
                 "DecompilerVersion" => "",
                 "ContractName" => contract.name,
                 "OptimizationUsed" => if(contract.optimization, do: "1", else: "0"),
                 "SourceCode" => contract.contract_source_code
               }
             ]
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
                 "Address" => to_string(decompiled_smart_contract.address_hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => decompiled_smart_contract.decompiled_source_code,
                 "DecompilerVersion" => "test_decompiler",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
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
                 "Address" => to_string(smart_contract.address_hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => smart_contract.decompiled_source_code,
                 "DecompilerVersion" => "bizbuz",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
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

      assert response["result"] == [
               %{
                 "ABI" => "Contract source code not verified",
                 "Address" => to_string(smart_contract.address_hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => smart_contract.decompiled_source_code,
                 "DecompilerVersion" => "bizbuz",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
    end

    test "filtering for only not_decompiled (and by extension not verified contracts)", %{params: params, conn: conn} do
      insert(:decompiled_smart_contract)
      insert(:smart_contract)
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
                 "Address" => to_string(contract_address.hash),
                 "CompilerVersion" => "",
                 "ContractName" => "",
                 "DecompiledSourceCode" => "Contract source code not decompiled.",
                 "DecompilerVersion" => "",
                 "OptimizationUsed" => "",
                 "SourceCode" => ""
               }
             ]
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
    end

    test "with a verified contract address", %{conn: conn} do
      contract = insert(:smart_contract)

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
          "DecompilerVersion" => ""
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a verified contract address", %{conn: conn} do
      contract = insert(:smart_contract, optimization: true)

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
          "DecompiledSourceCode" => "Contract source code not decompiled.",
          # The contract's optimization value is true, so the expected value
          # for `OptimizationUsed` is "1". If it was false, the expected value
          # would be "0".
          "DecompilerVersion" => "",
          "OptimizationUsed" => "1"
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "verify" do
    test "with an address that doesn't exist", %{conn: conn} do
      contract_code_info = Factory.contract_code_info()

      contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

      params = %{
        "module" => "contract",
        "action" => "verify",
        "addressHash" => to_string(contract_address.hash),
        "name" => contract_code_info.name,
        "compilerVersion" => contract_code_info.version,
        "optimization" => contract_code_info.optimized,
        "contractSourceCode" => contract_code_info.source_code
      }

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      expected_result = %{
        "Address" => to_string(contract_address.hash),
        "SourceCode" => contract_code_info.source_code,
        "ABI" => Jason.encode!(contract_code_info.abi),
        "ContractName" => contract_code_info.name,
        "CompilerVersion" => contract_code_info.version,
        "DecompiledSourceCode" => "Contract source code not decompiled.",
        "DecompilerVersion" => "",
        "OptimizationUsed" => "0"
      }

      assert response["status"] == "1"
      assert response["result"] == expected_result
      assert response["message"] == "OK"
    end

    test "with external libraries", %{conn: conn} do
      contract_data =
        "#{File.cwd!()}/test/support/fixture/smart_contract/compiler_tests.json"
        |> File.read!()
        |> Jason.decode!()
        |> List.first()

      %{
        "compiler_version" => compiler_version,
        "external_libraries" => external_libraries,
        "name" => name,
        "optimize" => optimize,
        "contract" => contract_source_code,
        "expected_bytecode" => expected_bytecode
      } = contract_data

      contract_address = insert(:contract_address, contract_code: "0x" <> expected_bytecode)

      params = %{
        "module" => "contract",
        "action" => "verify",
        "addressHash" => to_string(contract_address.hash),
        "name" => name,
        "compilerVersion" => compiler_version,
        "optimization" => optimize,
        "contractSourceCode" => contract_source_code
      }

      params_with_external_libraries =
        external_libraries
        |> Enum.with_index()
        |> Enum.reduce(params, fn {{name, address}, index}, acc ->
          name_key = "library#{index + 1}Name"
          address_key = "library#{index + 1}Address"

          acc
          |> Map.put(name_key, name)
          |> Map.put(address_key, address)
        end)

      response =
        conn
        |> get("/api", params_with_external_libraries)
        |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"

      result = response["result"]

      assert result["Address"] == to_string(contract_address.hash)
      assert result["SourceCode"] == contract_source_code
      assert result["ContractName"] == name
      assert result["DecompiledSourceCode"] == "Contract source code not decompiled."
      assert result["DecompilerVersion"] == ""
      assert result["OptimizationUsed"] == "1"
    end
  end
end
