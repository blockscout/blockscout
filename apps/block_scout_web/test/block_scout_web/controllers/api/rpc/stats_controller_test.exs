defmodule BlockScoutWeb.API.RPC.StatsControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.TestSource

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

  describe "ethprice" do
    setup :set_mox_global

    setup do
      # Use TestSource mock for this test set
      configuration = Application.get_env(:explorer, Explorer.ExchangeRates)
      Application.put_env(:explorer, Explorer.ExchangeRates, source: TestSource)
      Application.put_env(:explorer, Explorer.ExchangeRates, table_name: :rates)

      ExchangeRates.init([])

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.ExchangeRates, configuration)
      end)
    end

    test "returns the configured coin's price information", %{conn: conn} do
      symbol = Application.get_env(:explorer, :coin)

      eth = %Token{
        available_supply: Decimal.new("1000000.0"),
        total_supply: Decimal.new("1000000.0"),
        btc_value: Decimal.new("1.000"),
        id: "test",
        last_updated: DateTime.utc_now(),
        market_cap_usd: Decimal.new("1000000.0"),
        name: "test",
        symbol: symbol,
        usd_value: Decimal.new("1.0"),
        volume_24h_usd: Decimal.new("1000.0")
      }

      ExchangeRates.handle_info({nil, {:ok, [eth]}}, %{})

      params = %{
        "module" => "stats",
        "action" => "ethprice"
      }

      expected_timestamp = eth.last_updated |> DateTime.to_unix() |> to_string()

      expected_result = %{
        "ethbtc" => to_string(eth.btc_value),
        "ethbtc_timestamp" => expected_timestamp,
        "ethusd" => to_string(eth.usd_value),
        "ethusd_timestamp" => expected_timestamp
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
end
