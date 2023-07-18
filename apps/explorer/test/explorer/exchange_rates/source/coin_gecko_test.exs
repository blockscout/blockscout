defmodule Explorer.ExchangeRates.Source.CoinGeckoTest do
  use ExUnit.Case

  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.CoinGecko
  alias Plug.Conn

  @json_btc_price """
  {
    "rates": {
      "usd": {
        "name": "US Dollar",
        "unit": "$",
        "value": 6547.418,
        "type": "fiat"
      }
    }
  }
  """

  @coins_list """
  [
    {
      "id": "poa-network",
      "symbol": "poa",
      "name": "POA Network"
    },
    {
      "id": "poc-chain",
      "symbol": "pocc",
      "name": "POC Chain"
    },
    {
      "id": "pocket-arena",
      "symbol": "poc",
      "name": "Pocket Arena"
    },
    {
    "id": "ethereum",
    "symbol": "eth",
    "name": "Ethereum"
    },
    {
      "id": "rootstock",
      "symbol": "rbtc",
      "name": "Rootstock RSK"
    },
    {
      "id": "dai",
      "symbol": "dai",
      "name": "Dai"
    },
    {
      "id": "callisto",
      "symbol": "clo",
      "name": "Callisto Network"
    }
  ]
  """

  describe "source_url/1" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CoinGecko, base_url: "https://api.coingecko.com/api/v3")

      {:ok, bypass: bypass}
    end

    test "composes cg :coins_list URL" do
      assert "https://api.coingecko.com/api/v3/coins/list?include_platform=true" == CoinGecko.source_url(:coins_list)
    end

    test "composes cg url to list of contract address hashes" do
      assert "https://api.coingecko.com/api/v3/simple/token_price/ethereum?vs_currencies=usd&include_market_cap=true&contract_addresses=0xdAC17F958D2ee523a2206206994597C13D831ec7" ==
               CoinGecko.source_url(["0xdAC17F958D2ee523a2206206994597C13D831ec7"])
    end

    test "composes cg url by contract address hash" do
      assert "https://api.coingecko.com/api/v3/coins/ethereum/contract/0xdAC17F958D2ee523a2206206994597C13D831ec7" ==
               CoinGecko.source_url("0xdAC17F958D2ee523a2206206994597C13D831ec7")
    end

    test "composes cg url by contract address hash with custom coin_id" do
      Application.put_env(:explorer, CoinGecko, platform: "poa-network")

      assert "https://api.coingecko.com/api/v3/coins/poa-network/contract/0xdAC17F958D2ee523a2206206994597C13D831ec7" ==
               CoinGecko.source_url("0xdAC17F958D2ee523a2206206994597C13D831ec7")

      Application.put_env(:explorer, CoinGecko, platform: nil)
    end
  end

  describe "format_data/1" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CoinGecko, base_url: "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "returns valid tokens with valid data", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/exchange_rates", fn conn ->
        Conn.resp(conn, 200, @json_btc_price)
      end)

      json_data =
        "#{File.cwd!()}/test/support/fixture/exchange_rates/coin_gecko.json"
        |> File.read!()
        |> Jason.decode!()

      expected = [
        %Token{
          available_supply: Decimal.new("220167621.0"),
          total_supply: Decimal.new("252193195.0"),
          btc_value: Decimal.new("0.000002055310963802830367634997491"),
          id: "poa-network",
          last_updated: ~U[2019-08-21 08:36:49.371Z],
          market_cap_usd: Decimal.new("2962791"),
          name: "POA Network",
          symbol: "POA",
          usd_value: Decimal.new("0.01345698"),
          volume_24h_usd: Decimal.new("119946")
        }
      ]

      assert expected == CoinGecko.format_data(json_data)
    end

    test "returns nothing when given bad data" do
      bad_data = """
        [{"id": "poa-network"}]
      """

      assert [] = CoinGecko.format_data(bad_data)
    end
  end

  describe "coin_id/0" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CoinGecko, base_url: "http://localhost:#{bypass.port}")

      on_exit(fn ->
        Application.put_env(:explorer, :coin, "POA")
      end)

      {:ok, bypass: bypass}
    end

    test "fetches poa coin id", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "POA")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 200, @coins_list)
      end)

      assert CoinGecko.coin_id() == {:ok, "poa-network"}
    end

    test "fetches eth coin id", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "ETH")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 200, @coins_list)
      end)

      assert CoinGecko.coin_id() == {:ok, "ethereum"}
    end

    test "fetches rbtc coin id", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "RBTC")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 200, @coins_list)
      end)

      assert CoinGecko.coin_id() == {:ok, "rootstock"}
    end

    test "fetches dai coin id", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "DAI")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 200, @coins_list)
      end)

      assert CoinGecko.coin_id() == {:ok, "dai"}
    end

    test "fetches callisto coin id", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "CLO")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 200, @coins_list)
      end)

      assert CoinGecko.coin_id() == {:ok, "callisto"}
    end

    test "returns redirect on fetching", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "DAI")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 302, "Request redirected...")
      end)

      assert CoinGecko.coin_id() == {:error, "Source redirected"}
    end

    test "returns error on fetching", %{bypass: bypass} do
      Application.put_env(:explorer, :coin, "DAI")

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        Conn.resp(conn, 503, "Internal server error...")
      end)

      assert CoinGecko.coin_id() == {:error, "Internal server error..."}
    end
  end
end
