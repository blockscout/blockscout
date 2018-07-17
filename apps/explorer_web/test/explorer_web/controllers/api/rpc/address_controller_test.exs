defmodule ExplorerWeb.API.RPC.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain.Wei

  describe "balance" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(400)

      assert response["message"] =~ "'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(400)

      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "0"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a valid address", %{conn: conn} do
      address = insert(:address, fetched_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "#{address.hash}"
      }

      expected_balance =
        address.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_balance
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..2 do
          insert(:address, fetched_balance: Enum.random(1..1_000))
        end

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => address_param
      }

      expected_result =
        Enum.map(addresses, fn address ->
          expected_balance =
            address.fetched_balance
            |> Wei.to(:ether)
            |> Decimal.to_string(:normal)

          %{"account" => "#{address.hash}", "balance" => expected_balance}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "balancemulti" do
    test "with an invalid and a valid address hash", %{conn: conn} do
      address1 = "invalidhash"
      address2 = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1},#{address2}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(400)

      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with multiple addresses that don't exist", %{conn: conn} do
      address1 = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      address2 = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1},#{address2}"
      }

      expected_result = [
        %{"account" => address1, "balance" => "0"},
        %{"account" => address2, "balance" => "0"}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..4 do
          insert(:address, fetched_balance: Enum.random(1..1_000))
        end

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => address_param
      }

      expected_result =
        Enum.map(addresses, fn address ->
          expected_balance =
            address.fetched_balance
            |> Wei.to(:ether)
            |> Decimal.to_string(:normal)

          %{"account" => "#{address.hash}", "balance" => expected_balance}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with an address that exists and one that doesn't", %{conn: conn} do
      address1 = insert(:address, fetched_balance: 100)
      address2_hash = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1.hash},#{address2_hash}"
      }

      expected_balance1 =
        address1.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      expected_result = [
        %{"account" => address2_hash, "balance" => "0"},
        %{"account" => "#{address1.hash}", "balance" => expected_balance1}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "up to a maximum of 20 addresses in a single request", %{conn: conn} do
      addresses = insert_list(25, :address, fetched_balance: 0)

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => address_param
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 20
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a single address", %{conn: conn} do
      address = insert(:address, fetched_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address.hash}"
      }

      expected_balance =
        address.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      expected_result = [
        %{"account" => "#{address.hash}", "balance" => expected_balance}
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
