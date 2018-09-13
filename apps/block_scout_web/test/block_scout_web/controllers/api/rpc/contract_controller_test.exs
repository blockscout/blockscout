defmodule BlockScoutWeb.API.RPC.ContractControllerTest do
  use BlockScoutWeb.ConnCase

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
          "SourceCode" => "",
          "ABI" => "Contract source code not verified",
          "ContractName" => "",
          "CompilerVersion" => "",
          "OptimizationUsed" => ""
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
          "SourceCode" => contract.contract_source_code,
          "ABI" => Jason.encode!(contract.abi),
          "ContractName" => contract.name,
          "CompilerVersion" => contract.compiler_version,
          # The contract's optimization value is true, so the expected value
          # for `OptimzationUsed` is "1". If it was false, the expected value
          # would be "0".
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
end
