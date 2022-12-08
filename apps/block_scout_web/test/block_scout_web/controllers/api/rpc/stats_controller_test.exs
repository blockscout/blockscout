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

      assert response["message"] =~ "contract address not found"
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

    test "with coinmarketcap param", %{conn: conn} do
      token = insert(:token, %{total_supply: 777.777})

      params = %{
        "module" => "stats",
        "action" => "tokensupply",
        "cmc" => true,
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert "777.777" ==
               conn
               |> get("/api", params)
               |> text_response(200)
    end
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

      assert response["result"] == "252460800000000000000000000"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(ethsupplyexchange_schema(), response)
    end
  end

  describe "celounlocked" do
    test "returns total sum and available sum of unlocked CELO", %{conn: conn} do
      available_1 = Timex.shift(DateTime.utc_now(), days: -1)
      available_2 = Timex.shift(DateTime.utc_now(), days: 1)
      address_1 = insert(:address)
      address_2 = insert(:address)

      pending_withdrawal_1 =
        insert(:celo_unlocked, %{
          account_address: address_1.hash,
          amount: 3_000_000_000_000_000_000,
          available: available_1
        })

      pending_withdrawal_2 =
        insert(:celo_unlocked, %{
          account_address: address_2.hash,
          amount: 2_000_000_000_000_000_000,
          available: available_1
        })

      pending_withdrawal_3 =
        insert(:celo_unlocked, %{
          account_address: address_2.hash,
          amount: 1_000_000_000_000_000_000,
          available: available_2
        })

      params = %{
        "module" => "stats",
        "action" => "celounlocked"
      }

      expected_result = [
        %{
          "total" =>
            to_string(
              Explorer.Chain.Wei.to(pending_withdrawal_1.amount, :wei)
              |> Decimal.add(Explorer.Chain.Wei.to(pending_withdrawal_2.amount, :wei))
              |> Decimal.add(Explorer.Chain.Wei.to(pending_withdrawal_3.amount, :wei))
            ),
          "availableForWithdrawal" =>
            to_string(
              Decimal.add(
                Explorer.Chain.Wei.to(pending_withdrawal_1.amount, :wei),
                Explorer.Chain.Wei.to(pending_withdrawal_2.amount, :wei)
              )
            )
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(celounlocked_schema(), response)
    end
  end

  # todo: Temporarily disable this test because of unstable work in CI
  # describe "ethsupply" do
  #   test "returns total supply from DB", %{conn: conn} do
  #     params = %{
  #       "module" => "stats",
  #       "action" => "ethsupply"
  #     }

  #     assert response =
  #              conn
  #              |> get("/api", params)
  #              |> json_response(200)

  #     assert response["result"] == "0"
  #     assert response["status"] == "1"
  #     assert response["message"] == "OK"
  #     assert :ok = ExJsonSchema.Validator.validate(ethsupply_schema(), response)
  #   end
  # end

  # describe "coinsupply" do
  #   test "returns total supply minus a burnt number from DB in coins denomination", %{conn: conn} do
  #     params = %{
  #       "module" => "stats",
  #       "action" => "coinsupply"
  #     }

  #     assert response =
  #              conn
  #              |> get("/api", params)
  #              |> json_response(200)

  #     assert response == 0.0
  #   end
  # end

  describe "coinprice" do
    setup :set_mox_global

    setup do
      # Use TestSource mock for this test set
      configuration = Application.get_env(:explorer, Explorer.ExchangeRates)
      Application.put_env(:explorer, Explorer.ExchangeRates, source: TestSource)
      Application.put_env(:explorer, Explorer.ExchangeRates, table_name: :rates)
      Application.put_env(:explorer, Explorer.ExchangeRates, enabled: true)

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
        "action" => "coinprice"
      }

      expected_timestamp = eth.last_updated |> DateTime.to_unix() |> to_string()

      expected_result = %{
        "coin_btc" => to_string(eth.btc_value),
        "coin_btc_timestamp" => expected_timestamp,
        "coin_usd" => to_string(eth.usd_value),
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

  defp tokensupply_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  # defp ethsupply_schema do
  #   resolve_schema(%{
  #     "type" => ["string", "null"]
  #   })
  # end

  defp ethsupplyexchange_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp celounlocked_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "total" => %{"type" => "string"},
          "available_for_withdrawal" => %{"type" => "string"}
        }
      }
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
