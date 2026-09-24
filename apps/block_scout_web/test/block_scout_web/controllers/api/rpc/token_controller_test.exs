# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TokenControllerTest do
  use BlockScoutWeb.ConnCase

  describe "gettoken" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "response includes all required fields", %{conn: conn} do
      token = insert(:token)

      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      expected_result = %{
        "name" => token.name,
        "symbol" => token.symbol,
        "totalSupply" => to_string(token.total_supply),
        "decimals" => to_string(token.decimals),
        "type" => token.type,
        "cataloged" => token.cataloged,
        "contractAddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "tokeninfo" do
    test "response includes all required fields", %{conn: conn} do
      token = insert(:token)

      params = %{
        "module" => "token",
        "action" => "tokeninfo",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      expected_result = %{
        "name" => token.name,
        "symbol" => token.symbol,
        "totalSupply" => to_string(token.total_supply),
        "decimals" => to_string(token.decimals),
        "type" => token.type,
        "cataloged" => token.cataloged,
        "contractAddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "tokenholderlist" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholderlist"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholderlist",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "returns token holders", %{conn: conn} do
      token = insert(:token)
      address = insert(:address)

      insert(
        :address_current_token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: token.contract_address_hash,
        value: 5000
      )

      params = %{
        "module" => "token",
        "action" => "tokenholderlist",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert response["result"] == [
               %{
                 "address" => to_string(address.hash),
                 "value" => 5000
               }
             ]
    end
  end

  describe "tokenholdercount" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "returns the count of token holders", %{conn: conn} do
      token = insert(:token)
      address_a = insert(:address)
      address_b = insert(:address)

      insert(
        :address_current_token_balance,
        address: address_a,
        block_number: 1000,
        token_contract_address_hash: token.contract_address_hash,
        value: 5000
      )

      insert(
        :address_current_token_balance,
        address: address_b,
        block_number: 1002,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      params = %{
        "module" => "token",
        "action" => "tokenholdercount",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert response["result"] == "2"
    end
  end
end
