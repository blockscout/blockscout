defmodule BlockScoutWeb.API.RPC.StatsControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain
  alias Explorer.Chain.Wei

  describe "tokensupply" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "tokensupply"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contractaddress is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contractaddress hash", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contractaddress format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contractaddress that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contractaddress not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with valid contractaddress", %{conn: conn} do
      token = insert(:token)

      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == to_string(token.total_supply)
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "ethsupply" do
    test "returns total supply", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "ethsupply"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "252460800000000000000000000"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end
end
