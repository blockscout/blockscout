defmodule Explorer.Market.Source.DIATest do
  use ExUnit.Case

  alias Explorer.Market.Source.DIA
  alias Plug.Conn

  @native_coin_history_json File.read!("./test/support/fixture/market/dia/native_coin_history.json")
  @secondary_coin_history_json File.read!("./test/support/fixture/market/dia/secondary_coin_history.json")

  setup do
    bypass = Bypass.open()
    old_env = Application.get_env(:explorer, DIA, [])

    new_env =
      Keyword.merge(
        old_env,
        blockchain: "Ethereum",
        base_url: "http://localhost:#{bypass.port}",
        coin_address_hash: "0x0000000000000000000000000000000000000000",
        secondary_coin_address_hash: "0x0000000000000000000000000000000000000001"
      )

    Application.put_env(
      :explorer,
      DIA,
      new_env
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, DIA, old_env)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, env: new_env, bypass: bypass}
  end

  describe "native_coin_fetching_enabled?" do
    test "returns true if coin_address_hash is configured" do
      assert DIA.native_coin_fetching_enabled?()
    end

    test "returns false if coin_address_hash is not configured", %{env: env} do
      Application.put_env(:explorer, DIA, Keyword.merge(env, coin_address_hash: nil))
      refute DIA.native_coin_fetching_enabled?()
    end
  end

  describe "fetch_native_coin" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/assetQuotation/Ethereum/0x0000000000000000000000000000000000000000",
        fn conn ->
          Conn.resp(
            conn,
            200,
            json_coin("0x0000000000000000000000000000000000000000", 3027.98578732332, "ETH", "Ethereum")
          )
        end
      )

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: nil,
                btc_value: nil,
                fiat_value: Decimal.new("3027.98578732332"),
                image_url: nil,
                last_updated: ~U[2025-11-27 08:09:59Z],
                market_cap: nil,
                name: "Ethereum",
                symbol: "ETH",
                total_supply: nil,
                tvl: nil,
                volume_24h: Decimal.new("6577658642.868258")
              }} ==
               DIA.fetch_native_coin()
    end
  end

  describe "secondary_coin_fetching_enabled?" do
    test "returns true if secondary_coin_address_hash is configured" do
      assert DIA.secondary_coin_fetching_enabled?()
    end

    test "returns false if secondary_coin_address_hash is not configured", %{env: env} do
      Application.put_env(:explorer, DIA, Keyword.merge(env, secondary_coin_address_hash: nil))

      refute DIA.secondary_coin_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin" do
    test "fetches secondary coin", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/assetQuotation/Ethereum/0x0000000000000000000000000000000000000001",
        fn conn ->
          Conn.resp(
            conn,
            200,
            json_coin("0x0000000000000000000000000000000000000001", 91169.97153780921, "WBTC", "Wrapped BTC")
          )
        end
      )

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: nil,
                btc_value: nil,
                fiat_value: Decimal.new("91169.97153780921"),
                image_url: nil,
                last_updated: ~U[2025-11-27 08:09:59Z],
                market_cap: nil,
                name: "Wrapped BTC",
                symbol: "WBTC",
                total_supply: nil,
                tvl: nil,
                volume_24h: Decimal.new("6577658642.868258")
              }} ==
               DIA.fetch_secondary_coin()
    end
  end

  describe "tokens_fetching_enabled?" do
    test "returns true if blockchain is configured" do
      assert DIA.tokens_fetching_enabled?()
    end

    test "returns false if blockchain is not configured", %{env: env} do
      Application.put_env(:explorer, DIA, Keyword.merge(env, blockchain: nil))

      refute DIA.tokens_fetching_enabled?()
    end
  end

  describe "fetch_tokens" do
    test "fetches tokens", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/quotedAssets", fn conn ->
        assert conn.query_string == "blockchain=Ethereum"
        Conn.resp(conn, 200, json_tokens_list())
      end)

      Bypass.expect(bypass, "GET", "/assetQuotation/Ethereum/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", fn conn ->
        Conn.resp(
          conn,
          200,
          json_coin("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 0.9997188333561603, "USDC", "USD Coin")
        )
      end)

      Bypass.expect(bypass, "GET", "/assetQuotation/Ethereum/0xdac17f958d2ee523a2206206994597c13d831ec7", fn conn ->
        Conn.resp(
          conn,
          200,
          json_coin("0xdAC17F958D2ee523a2206206994597C13D831ec7", 0.9999313493241913, "USDT", "Tether USD")
        )
      end)

      usdt_and_usdc_to_fetch = [
        %{
          contract_address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: "\xDA\xC1\d\x95\x8D.\xE5#\xA2 b\x06\x99E\x97\xC1=\x83\x1E\xC7"
          },
          decimals: 6
        },
        %{
          contract_address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: "\xA0\xB8i\x91\xC6!\x8B6\xC1ѝJ.\x9E\xB0\xCE6\x06\xEBH"
          },
          decimals: 6
        }
      ]

      usdt_and_usdc = [
        %{
          name: "Tether USD",
          type: "ERC-20",
          symbol: "USDT",
          contract_address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<218, 193, 127, 149, 141, 46, 229, 35, 162, 32, 98, 6, 153, 69, 151, 193, 61, 131, 30, 199>>
          },
          fiat_value: Decimal.new("0.9999313493241913"),
          volume_24h: Decimal.new("6577658642.868258"),
          decimals: 6
        },
        %{
          name: "USD Coin",
          type: "ERC-20",
          symbol: "USDC",
          contract_address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<160, 184, 105, 145, 198, 33, 139, 54, 193, 209, 157, 74, 46, 158, 176, 206, 54, 6, 235, 72>>
          },
          fiat_value: Decimal.new("0.9997188333561603"),
          volume_24h: Decimal.new("6577658642.868258"),
          decimals: 6
        }
      ]

      assert {:ok, [usdt_or_usdc_to_fetch] = state, false, [usdc_or_usdt_a]} = DIA.fetch_tokens(nil, 1)

      assert usdt_or_usdc_to_fetch in usdt_and_usdc_to_fetch

      assert {:ok, [], true, [usdc_or_usdt_b]} = DIA.fetch_tokens(state, 1)

      assert usdc_or_usdt_a in usdt_and_usdc
      assert usdc_or_usdt_b in usdt_and_usdc
      assert usdc_or_usdt_a != usdc_or_usdt_b
    end
  end

  describe "native_coin_price_history_fetching_enabled?" do
    test "returns true if coin_address_hash is configured" do
      assert DIA.native_coin_price_history_fetching_enabled?()
    end

    test "returns false if coin_address_hash is not configured", %{env: env} do
      Application.put_env(:explorer, DIA, Keyword.merge(env, coin_address_hash: nil))

      refute DIA.native_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_native_coin_price_history" do
    test "fetches native coin price history", %{bypass: bypass} do
      previous_days = 5

      Bypass.expect_once(
        bypass,
        "GET",
        "/assetChartPoints/MA120/Ethereum/0x0000000000000000000000000000000000000000",
        fn conn ->
          "starttime=" <> from_str = conn.query_string
          {from_int, "&endtime=" <> to_str} = Integer.parse(from_str)
          {to_int, ""} = Integer.parse(to_str)
          assert to_int - from_int == previous_days * 24 * 60 * 60
          Conn.resp(conn, 200, @native_coin_history_json)
        end
      )

      assert {:ok,
              [
                %{
                  closing_price: Decimal.new("2769.8064113406717"),
                  date: ~D[2025-11-22],
                  opening_price: Decimal.new("2765.03927910001"),
                  secondary_coin: false
                },
                %{
                  closing_price: Decimal.new("2801.5141364778983"),
                  date: ~D[2025-11-23],
                  opening_price: Decimal.new("2768.2062977060264"),
                  secondary_coin: false
                },
                %{
                  closing_price: Decimal.new("2952.88025966878"),
                  date: ~D[2025-11-24],
                  opening_price: Decimal.new("2798.783002464827"),
                  secondary_coin: false
                },
                %{
                  closing_price: Decimal.new("2959.1210339664754"),
                  date: ~D[2025-11-25],
                  opening_price: Decimal.new("2949.9206856724004"),
                  secondary_coin: false
                },
                %{
                  closing_price: Decimal.new("3027.151520522141"),
                  date: ~D[2025-11-26],
                  opening_price: Decimal.new("2959.062301250391"),
                  secondary_coin: false
                }
              ]} ==
               DIA.fetch_native_coin_price_history(previous_days)
    end
  end

  describe "secondary_coin_price_history_fetching_enabled?" do
    test "returns true if secondary_coin_address_hash is configured" do
      assert DIA.secondary_coin_price_history_fetching_enabled?()
    end

    test "returns false if secondary_coin_address_hash is not configured", %{env: env} do
      Application.put_env(:explorer, DIA, Keyword.merge(env, secondary_coin_address_hash: nil))
      refute DIA.secondary_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin_price_history" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      previous_days = 5

      Bypass.expect_once(
        bypass,
        "GET",
        "/assetChartPoints/MA120/Ethereum/0x0000000000000000000000000000000000000001",
        fn conn ->
          "starttime=" <> from_str = conn.query_string
          {from_int, "&endtime=" <> to_str} = Integer.parse(from_str)
          {to_int, ""} = Integer.parse(to_str)
          assert to_int - from_int == previous_days * 24 * 60 * 60
          Conn.resp(conn, 200, @secondary_coin_history_json)
        end
      )

      assert {:ok,
              [
                %{
                  closing_price: Decimal.new("1.0014961501515858"),
                  date: ~D[2025-11-22],
                  opening_price: Decimal.new("0.9998295379999973"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("1.0003179715114685"),
                  date: ~D[2025-11-23],
                  opening_price: Decimal.new("0.9998108086782626"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("0.9999003120252966"),
                  date: ~D[2025-11-24],
                  opening_price: Decimal.new("1.0000636244141254"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("0.9997550066438543"),
                  date: ~D[2025-11-25],
                  opening_price: Decimal.new("1.0006631013107907"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("0.9997050546597661"),
                  date: ~D[2025-11-26],
                  opening_price: Decimal.new("0.9998251538809131"),
                  secondary_coin: true
                }
              ]} ==
               DIA.fetch_secondary_coin_price_history(previous_days)
    end
  end

  describe "market_cap_history_fetching_enabled?" do
    test "ignored" do
      assert DIA.market_cap_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_market_cap_history" do
    test "ignored" do
      assert DIA.fetch_market_cap_history(0) == :ignore
    end
  end

  describe "tvl_history_fetching_enabled?" do
    test "ignored" do
      assert DIA.tvl_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_tvl_history" do
    test "ignored" do
      assert DIA.fetch_tvl_history(0) == :ignore
    end
  end

  # cspell:disable

  defp json_coin(coin_address_hash, fiat_value, symbol, name) do
    """
    {
      "Symbol": "#{symbol}",
      "Name": "#{name}",
      "Address": "#{coin_address_hash}",
      "Blockchain": "Ethereum",
      "Price": #{fiat_value},
      "PriceYesterday": 2935.2004802640054,
      "VolumeYesterdayUSD": 6577658642.868258,
      "Time": "2025-11-27T08:09:59Z",
      "Source": "diadata.org",
      "Signature": "0x5b080262b6ee4f5303251ef65dc81b61dc6e5ceb6e2ff0d9ca8a6c9175c0bef472bbadfe4a3a339134ebc094b4336fb6ad0e50bac3622968bb03819789b6dbea01"
    }
    """
  end

  defp json_tokens_list do
    """
    [
    {
    "Asset": {
    "Symbol": "ETH",
    "Name": "Ether",
    "Address": "0x0000000000000000000000000000000000000000",
    "Decimals": 18,
    "Blockchain": "Ethereum"
    },
    "Volume": 6577658642.868258,
    "VolumeUSD": 0,
    "Index": 0
    },
    {
    "Asset": {
    "Symbol": "USDC",
    "Name": "USD Coin",
    "Address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "Decimals": 6,
    "Blockchain": "Ethereum"
    },
    "Volume": 2756384237.21397,
    "VolumeUSD": 0,
    "Index": 0
    },
    {
    "Asset": {
    "Symbol": "USDT",
    "Name": "Tether USD",
    "Address": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "Decimals": 6,
    "Blockchain": "Ethereum"
    },
    "Volume": 504424765.759824,
    "VolumeUSD": 0,
    "Index": 0
    }
    ]
    """
  end

  # cspell:enable
end
