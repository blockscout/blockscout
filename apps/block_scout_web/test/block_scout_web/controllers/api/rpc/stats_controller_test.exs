defmodule BlockScoutWeb.API.RPC.StatsControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.Chain.Cache.Counters.{AddressesCoinBalanceSum, AddressesCoinBalanceSumMinusBurnt, LastFetchedCounter}
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Market.Fetcher.Coin
  alias Explorer.Market.Token
  alias Explorer.Market.Source.TestSource
  alias Explorer.Repo

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

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokensupply_schema(), response)
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokensupply_schema(), response)
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "tokensupply",
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
      assert :ok = ExJsonSchema.Validator.validate(tokensupply_schema(), response)
    end

    test "with valid contract address", %{conn: conn} do
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
      assert :ok = ExJsonSchema.Validator.validate(tokensupply_schema(), response)
    end

    test "with valid contract address and cmc format", %{conn: conn} do
      token = insert(:token, total_supply: 110_052_089_716_627_912_057_222_572)

      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => to_string(token.contract_address_hash),
        "cmc" => "true"
      }

      assert response =
               conn
               |> get("/api", params)
               |> text_response(200)

      assert response == "110052089.716627912"
    end

    test "with custom decimals and cmc format", %{conn: conn} do
      token =
        insert(:token,
          total_supply: 1_234_567_890,
          decimals: 6
        )

      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "contractaddress" => to_string(token.contract_address_hash),
        "cmc" => "true"
      }

      assert response =
               conn
               |> get("/api", params)
               |> text_response(200)

      assert response == "1234.567890000"
    end
  end

  test "with null decimals and cmc format", %{conn: conn} do
    token =
      insert(:token,
        total_supply: 1_234_567_890,
        decimals: nil
      )

    params = %{
      "module" => "stats",
      "action" => "tokensupply",
      "contractaddress" => to_string(token.contract_address_hash),
      "cmc" => "true"
    }

    assert response =
             conn
             |> get("/api", params)
             |> text_response(200)

    assert response == "1234567890.000000000"
  end

  describe "ethsupplyexchange" do
    test "returns total supply from exchange", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "ethsupplyexchange"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert Decimal.compare(Decimal.new(response["result"]), Decimal.new(0)) in [:eq, :gt]
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(ethsupplyexchange_schema(), response)
    end
  end

  describe "ethsupply" do
    test "returns cached total supply from counter", %{conn: conn} do
      AddressesCoinBalanceSum.set_sum(Decimal.new("3400000000000000000"))

      params = %{
        "module" => "stats",
        "action" => "ethsupply"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "3400000000000000000"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(ethsupply_schema(), response)
    end
  end

  describe "coinsupply" do
    test "returns value from cached sum minus burnt when it is positive", %{conn: conn} do
      AddressesCoinBalanceSumMinusBurnt.set_sum_minus_burnt(Decimal.new("2000000000000000000"))

      params = %{
        "module" => "stats",
        "action" => "coinsupply"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "2"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(coinsupply_schema(), response)
    end

    test "falls back to last fetched counter when cached sum minus burnt is non-positive", %{conn: conn} do
      AddressesCoinBalanceSumMinusBurnt.set_sum_minus_burnt(Decimal.new(0))

      LastFetchedCounter.upsert(%{
        counter_type: "sum_coin_total_supply_minus_burnt",
        value: Decimal.new("1500000000000000000")
      })

      params = %{
        "module" => "stats",
        "action" => "coinsupply"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "1.5"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(coinsupply_schema(), response)
    end
  end

  describe "ethprice" do
    setup :set_mox_global

    setup do
      coin_fetcher_configuration = Application.get_env(:explorer, Coin)
      market_source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

      Application.put_env(:explorer, Explorer.Market.Source, native_coin_source: TestSource)
      Application.put_env(:explorer, Coin, Keyword.merge(coin_fetcher_configuration, table_name: :rates, enabled: true))

      Coin.init([])

      on_exit(fn ->
        Application.put_env(:explorer, Coin, coin_fetcher_configuration)
        Application.put_env(:explorer, Explorer.Market.Source, market_source_configuration)
      end)

      :ok
    end

    test "returns the configured native coin price information with eth keys", %{conn: conn} do
      symbol = Application.get_env(:explorer, :coin)

      eth = %Token{
        available_supply: Decimal.new("1000000.0"),
        total_supply: Decimal.new("1000000.0"),
        btc_value: Decimal.new("1.000"),
        last_updated: DateTime.utc_now(),
        market_cap: Decimal.new("1000000.0"),
        tvl: Decimal.new("2000000.0"),
        name: "test",
        symbol: symbol,
        fiat_value: Decimal.new("1.0"),
        volume_24h: Decimal.new("1000.0"),
        image_url: nil
      }

      Coin.handle_info({nil, {{:ok, eth}, false}}, %{})

      params = %{
        "module" => "stats",
        "action" => "ethprice"
      }

      expected_timestamp = eth.last_updated |> DateTime.to_unix() |> to_string()

      expected_result = %{
        "ethbtc" => to_string(eth.btc_value),
        "ethbtc_timestamp" => expected_timestamp,
        "ethusd" => to_string(eth.fiat_value),
        "ethusd_timestamp" => expected_timestamp
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(ethprice_schema(), response)
    end
  end

  describe "coinprice" do
    setup :set_mox_global

    setup do
      # Use TestSource mock for this test set
      coin_fetcher_configuration = Application.get_env(:explorer, Coin)
      market_source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

      Application.put_env(:explorer, Explorer.Market.Source, native_coin_source: TestSource)
      Application.put_env(:explorer, Coin, Keyword.merge(coin_fetcher_configuration, table_name: :rates, enabled: true))

      Coin.init([])

      on_exit(fn ->
        Application.put_env(:explorer, Coin, coin_fetcher_configuration)
        Application.put_env(:explorer, Explorer.Market.Source, market_source_configuration)
      end)

      :ok
    end

    test "returns the configured coin's price information", %{conn: conn} do
      symbol = Application.get_env(:explorer, :coin)

      eth = %Token{
        available_supply: Decimal.new("1000000.0"),
        total_supply: Decimal.new("1000000.0"),
        btc_value: Decimal.new("1.000"),
        last_updated: DateTime.utc_now(),
        market_cap: Decimal.new("1000000.0"),
        tvl: Decimal.new("2000000.0"),
        name: "test",
        symbol: symbol,
        fiat_value: Decimal.new("1.0"),
        volume_24h: Decimal.new("1000.0"),
        image_url: nil
      }

      Coin.handle_info({nil, {{:ok, eth}, false}}, %{})

      params = %{
        "module" => "stats",
        "action" => "coinprice"
      }

      expected_timestamp = eth.last_updated |> DateTime.to_unix() |> to_string()

      expected_result = %{
        "coin_btc" => to_string(eth.btc_value),
        "coin_btc_timestamp" => expected_timestamp,
        "coin_usd" => to_string(eth.fiat_value),
        "coin_usd_timestamp" => expected_timestamp
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(coinprice_schema(), response)
    end
  end

  describe "totalfees" do
    test "returns error when date input is missing", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "totalfees"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == "Required date input is missing."
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(totalfees_schema(), response)
    end

    test "returns error for invalid date format", %{conn: conn} do
      params = %{
        "module" => "stats",
        "action" => "totalfees",
        "date" => "2026/01/01"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == "An incorrect input date provided. It should be in ISO 8601 format (yyyy-mm-dd)."
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(totalfees_schema(), response)
    end

    test "returns total fees for valid date", %{conn: conn} do
      target_date = ~D[2026-01-10]

      Repo.insert_all(TransactionStats, [
        %{date: target_date, number_of_transactions: 3, gas_used: Decimal.new("1250.0"), total_fee: Decimal.new("42")}
      ])

      params = %{
        "module" => "stats",
        "action" => "totalfees",
        "date" => Date.to_iso8601(target_date)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "42"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(totalfees_schema(), response)
    end
  end

  defp tokensupply_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp ethsupply_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp coinsupply_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp ethsupplyexchange_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp coinprice_schema do
    resolve_schema(%{
      "type" => "object",
      "properties" => %{
        "coin_btc" => %{"type" => "string"},
        "coin_btc_timestamp" => %{"type" => "string"},
        "coin_usd" => %{"type" => "string"},
        "coin_usd_timestamp" => %{"type" => "string"}
      }
    })
  end

  defp ethprice_schema do
    resolve_schema(%{
      "type" => "object",
      "properties" => %{
        "ethbtc" => %{"type" => "string"},
        "ethbtc_timestamp" => %{"type" => "string"},
        "ethusd" => %{"type" => "string"},
        "ethusd_timestamp" => %{"type" => "string"}
      }
    })
  end

  defp totalfees_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

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
