defmodule Explorer.Market.Source.CryptoRankTest do
  use ExUnit.Case

  alias Explorer.Market.Source.CryptoRank
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    old_env = Application.get_env(:explorer, CryptoRank, [])

    Application.put_env(
      :explorer,
      CryptoRank,
      Keyword.merge(
        old_env,
        platform: 96,
        base_url: "http://localhost:#{bypass.port}",
        api_key: "api_key",
        coin_id: "3",
        secondary_coin_id: "4"
      )
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, CryptoRank, old_env)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, old_env: old_env, bypass: bypass}
  end

  describe "native_coin_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert CryptoRank.native_coin_fetching_enabled?()
    end

    test "returns false if coin_id is not configured", %{old_env: old_env} do
      Application.put_env(:explorer, CryptoRank, Keyword.merge(old_env, coin_id: nil))

      refute CryptoRank.native_coin_fetching_enabled?()
    end
  end

  describe "fetch_native_coin" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/currencies/3", fn conn ->
        assert conn.query_string == "api_key=api_key"
        Conn.resp(conn, 200, json_coin(3, 2514.75325703684))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120723694"),
                btc_value: Decimal.new("0.0241643324256002"),
                fiat_value: Decimal.new("2514.75325703684"),
                image_url: "https://img.cryptorank.io/coins/60x60.ethereum1524754015525.png",
                last_updated: ~U[2025-06-02 14:22:32.759Z],
                market_cap: Decimal.new("303823300492.5147"),
                name: "Ethereum",
                symbol: "ETH",
                total_supply: Decimal.new("120723694"),
                tvl: nil,
                volume_24h: Decimal.new("5826359746")
              }} ==
               CryptoRank.fetch_native_coin()
    end
  end

  describe "secondary_coin_fetching_enabled?" do
    test "returns true if secondary_coin_id is configured" do
      assert CryptoRank.secondary_coin_fetching_enabled?()
    end

    test "returns false if secondary_coin_id is not configured", %{old_env: old_env} do
      Application.put_env(:explorer, CryptoRank, Keyword.merge(old_env, secondary_coin_id: nil))

      refute CryptoRank.secondary_coin_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin" do
    test "fetches secondary coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/currencies/4", fn conn ->
        assert conn.query_string == "api_key=api_key"
        Conn.resp(conn, 200, json_coin(4, 1000.123456789))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120723694"),
                btc_value: Decimal.new("0.0241643324256002"),
                fiat_value: Decimal.new("1000.123456789"),
                image_url: "https://img.cryptorank.io/coins/60x60.ethereum1524754015525.png",
                last_updated: ~U[2025-06-02 14:22:32.759Z],
                market_cap: Decimal.new("303823300492.5147"),
                name: "Ethereum",
                symbol: "ETH",
                total_supply: Decimal.new("120723694"),
                tvl: nil,
                volume_24h: Decimal.new("5826359746")
              }} ==
               CryptoRank.fetch_secondary_coin()
    end
  end

  describe "tokens_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert CryptoRank.tokens_fetching_enabled?()
    end

    test "returns false if coin_id is not configured", %{old_env: old_env} do
      Application.put_env(:explorer, CryptoRank, Keyword.merge(old_env, platform: nil))

      refute CryptoRank.tokens_fetching_enabled?()
    end
  end

  describe "fetch_tokens" do
    test "fetches tokens", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/dedicated/blockscout/currencies/contracts/96", fn conn ->
        case conn.query_string do
          "api_key=api_key&limit=50&skip=0" ->
            Conn.resp(conn, 200, json_tokens())

          "api_key=api_key&limit=50&skip=50" ->
            Conn.resp(conn, 200, json_tokens_2nd_page())

          _ ->
            raise "Unexpected query string: #{conn.query_string}"
        end
      end)

      assert {:ok, 50, false, first_batch} = CryptoRank.fetch_tokens(nil, 50)
      assert length(first_batch) == 50

      # cspell:disable

      assert {
               :ok,
               nil,
               true,
               [
                 %{
                   name: "Heurist",
                   type: "ERC-20",
                   symbol: "HEU",
                   contract_address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes:
                       <<171, 236, 94, 203, 224, 139, 108, 2, 245, 201, 162, 255, 130, 105, 110, 30, 125, 182, 249,
                         191>>
                   },
                   fiat_value: Decimal.new("0.019624517115"),
                   circulating_market_cap: Decimal.new("3046537.982244971760"),
                   volume_24h: Decimal.new("214644.7428230154531300")
                 },
                 %{
                   name: "Zyfi",
                   type: "ERC-20",
                   symbol: "ZFI",
                   contract_address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<93, 13, 123, 202, 5, 14, 46, 152, 253, 74, 94, 141, 59, 168, 35, 180, 159, 57, 134, 141>>
                   },
                   fiat_value: Decimal.new("0.004467522847"),
                   circulating_market_cap: Decimal.new("1019602.903569369320"),
                   volume_24h: Decimal.new("527.5318580293320804")
                 }
               ]
             } == CryptoRank.fetch_tokens(50, 50)

      # cspell:enable
    end
  end

  describe "native_coin_price_history_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert CryptoRank.native_coin_price_history_fetching_enabled?()
    end

    test "returns false if coin_id is not configured", %{old_env: old_env} do
      Application.put_env(:explorer, CryptoRank, Keyword.merge(old_env, coin_id: nil))

      refute CryptoRank.native_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_native_coin_price_history" do
    test "fetches native coin price history", %{bypass: bypass} do
      previous_days = 5
      from = Date.utc_today() |> Date.add(-previous_days) |> Date.to_iso8601()
      to = Date.utc_today() |> Date.to_iso8601()

      Bypass.expect_once(bypass, "GET", "/currencies/3/sparkline", fn conn ->
        assert conn.query_string == "api_key=api_key&interval=1d&from=#{from}&to=#{to}"

        Conn.resp(conn, 200, json_native_coin_history())
      end)

      assert {:ok,
              [
                %{
                  closing_price: Decimal.new("2681.794582393094"),
                  date: ~D[2025-05-28],
                  opening_price: Decimal.new("2662.609005038795"),
                  secondary_coin: false
                },
                %{
                  closing_price: Decimal.new("2631.742984069461"),
                  date: ~D[2025-05-29],
                  opening_price: Decimal.new("2681.794582393094"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-05-30],
                  closing_price: Decimal.new("2532.024768716731"),
                  opening_price: Decimal.new("2631.742984069461"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-05-31],
                  closing_price: Decimal.new("2528.507007933771"),
                  opening_price: Decimal.new("2532.024768716731"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-06-01],
                  closing_price: Decimal.new("2528.507007933771"),
                  opening_price: Decimal.new("2528.507007933771"),
                  secondary_coin: false
                }
              ]} ==
               CryptoRank.fetch_native_coin_price_history(previous_days)
    end
  end

  describe "secondary_coin_price_history_fetching_enabled?" do
    test "returns true if secondary_coin_id is configured" do
      assert CryptoRank.secondary_coin_price_history_fetching_enabled?()
    end

    test "returns false if secondary_coin_id is not configured", %{old_env: old_env} do
      Application.put_env(:explorer, CryptoRank, Keyword.merge(old_env, secondary_coin_id: nil))

      refute CryptoRank.secondary_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin_price_history" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      previous_days = 5
      from = Date.utc_today() |> Date.add(-previous_days) |> Date.to_iso8601()
      to = Date.utc_today() |> Date.to_iso8601()

      Bypass.expect_once(bypass, "GET", "/currencies/4/sparkline", fn conn ->
        assert conn.query_string == "api_key=api_key&interval=1d&from=#{from}&to=#{to}"

        Conn.resp(conn, 200, json_secondary_coin_history())
      end)

      assert {:ok,
              [
                %{
                  closing_price: Decimal.new("6.558096674134"),
                  date: ~D[2025-05-28],
                  opening_price: Decimal.new("6.669271727877"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("6.443746862121"),
                  date: ~D[2025-05-29],
                  opening_price: Decimal.new("6.558096674134"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("5.80657534093"),
                  date: ~D[2025-05-30],
                  opening_price: Decimal.new("6.443746862121"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("5.903371964672"),
                  date: ~D[2025-05-31],
                  opening_price: Decimal.new("5.80657534093"),
                  secondary_coin: true
                },
                %{
                  closing_price: Decimal.new("5.903371964672"),
                  date: ~D[2025-06-01],
                  opening_price: Decimal.new("5.903371964672"),
                  secondary_coin: true
                }
              ]} ==
               CryptoRank.fetch_secondary_coin_price_history(previous_days)
    end
  end

  describe "market_cap_history_fetching_enabled?" do
    test "ignored" do
      assert CryptoRank.market_cap_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_market_cap_history" do
    test "ignored" do
      assert CryptoRank.fetch_market_cap_history(0) == :ignore
    end
  end

  describe "tvl_history_fetching_enabled?" do
    test "ignored" do
      assert CryptoRank.tvl_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_tvl_history" do
    test "ignored" do
      assert CryptoRank.fetch_tvl_history(0) == :ignore
    end
  end

  defp json_coin(coin_id, fiat_value) do
    """
    {
      "data": {
        "id": #{coin_id},
        "rank": 2,
        "slug": "ethereum",
        "name": "Ethereum",
        "symbol": "ETH",
        "category": "Chain",
        "type": "coin",
        "volume24hBase": 2315094.5634,
        "circulatingSupply": 120723694,
        "totalSupply": 120723694,
        "images": {
          "16x16": "https://img.cryptorank.io/coins/icon.ethereum1524754015525.png",
          "200x200": "https://img.cryptorank.io/coins/ethereum1524754015525.png",
          "60x60": "https://img.cryptorank.io/coins/60x60.ethereum1524754015525.png"
        },
        "values": {
          "USD": {
            "price": #{fiat_value},
            "volume24h": 5826359746,
            "high24h": 2546.560850604021,
            "low24h": 2480.175296733773,
            "marketCap": 303823300492.5147,
            "percentChange24h": 0.4248,
            "percentChange7d": -1.3799,
            "percentChange30d": 37.1343,
            "percentChange3m": 16.9385,
            "percentChange6m": -30.9087
          },
          "BTC": {
            "price": 0.0241643324256002,
            "volume24h": 55942,
            "high24h": 0.0241883039284151,
            "low24h": 0.0236807597840912,
            "marketCap": 2917207.4734624363,
            "percentChange24h": 0.8852,
            "percentChange7d": 3.8147,
            "percentChange30d": 26.8718,
            "percentChange3m": -3.0863,
            "percentChange6m": -36.4735
          },
          "ETH": {
            "price": 1,
            "volume24h": 2315094,
            "high24h": 1,
            "low24h": 1,
            "marketCap": 120723694,
            "percentChange24h": 0,
            "percentChange7d": 0,
            "percentChange30d": 0,
            "percentChange3m": 0,
            "percentChange6m": 0
          }
        },
        "lastUpdated": "2025-06-02T14:22:32.759Z",
        "tokens": []
      },
      "status": {
        "time": "2025-06-02T14:23:23.902Z",
        "success": true,
        "code": 200,
        "message": "OK",
        "responseTime": 1,
        "creditsCost": 1
      }
    }
    """
  end

  # cspell:disable
  defp json_tokens do
    """
    {  "data": [    {      "id": 16,      "slug": "tether",      "symbol": "USDT",      "name": "Tether",      "priceUSD": "1.000312118824",      "volume24hUSD": "34598333608.3056447616193232",      "circulatingSupply": "153148231147",      "contracts": [        {          "address": "0xdac17f958d2ee523a2206206994597c13d831ec7",          "chainId": 3        },        {          "address": "0x551a5dcac57c66aa010940c2dcff5da9c53aa53b",          "chainId": 18        },        {          "address": "0x493257fD37EDB34451f62EDf8D2a0C418852bA4C",          "chainId": 96        },        {          "address": "0x9636d3294e45823ec924c8d89dd1f1dffcf044e6",          "chainId": 21        },        {          "address": "0xfadbbf8ce7d5b7041be672561bba99f79c532e10",          "chainId": 47        },        {          "address": "0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d",          "chainId": 100        },        {          "address": "0x5f0155d08ef4aae2b500aefb64a3419da8bb611a",          "chainId": 121        },        {          "address": "0x5eDCCFcAC24A89F3b87f2bfAB618a509FA6e3105",          "chainId": 122        },        {          "address": "0xd378634119d2f7b3cf3d60e0b0f5e048e74ce3cf",          "chainId": 124        },        {          "address": "0x398dcA951cD4fc18264d995DCD171aa5dEbDa129",          "chainId": 134        },        {          "address": "0x02f9bebf5e54968d8cc2562356c91ecde135801b",          "chainId": 166        },        {          "address": "0x900101d06a7426441ae63e9ab3b9b0f63be145f1",          "chainId": 197        },        {          "address": "0x3a337a6ada9d885b6ad95ec48f9b75f197b5ae35",          "chainId": 487        },        {          "address": "0x0709F39376dEEe2A2dfC94A58EdEb2Eb9DF012bD",          "chainId": 489        },        {          "address": "KT1XnTn74bUtxHfDtBmm2bGZAQfhPbvKWR8o",          "chainId": 41        },        {          "address": "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs",          "chainId": 95        },        {          "address": "0xf0F161fDA2712DB8b566946122a5af183995e2eD",          "chainId": 150        },        {          "address": "0x28c9c7Fb3fE3104d2116Af26cC8eF7905547349c",          "chainId": 210        },        {          "address": "0x6fbcdc1169b5130c59e72e51ed68a84841c98cd1",          "chainId": 43        },        {          "address": "0x3795c36e7d12a8c252a20c5a7b455f7c57b60283",          "chainId": 83        },        {          "address": "0x919c1c267bc06a7039e03fcc2ef738525769109c",          "chainId": 81        },        {          "address": "0x201eba5cc46d216ce6dc03f6a759e8e766e956ae",          "chainId": 103        },        {          "address": "terra1ce06wkrdm4vl6t0hvc0g86rsy27pu8yadg3dva",          "chainId": 2        },        {          "address": "0x1e4a5963abfd975d8c9021ce480b42188849d41d",          "chainId": 102        },        {          "address": "0x6047828dc181963ba44974801FF68e538dA5eaF9",          "chainId": 465        },        {          "address": "0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b",          "chainId": 91        },        {          "address": "0x0039f574ee5cc39bdd162e9a88e3eb1f111baf48",          "chainId": 71        },        {          "address": "0xa71edc38d189767582c38a3145b5873052c3e47a",          "chainId": 14        },        {          "address": "0x3c2b8be99c50593081eaa2a724f0b8285f5aba8f",          "chainId": 12        },        {          "address": "0xc2132d05d31c914a87c6611c10748aeb04b58e8f",          "chainId": 5        },        {          "address": "0:a519f99bb5d6d51ef958ed24d337ad75a1c770885dcd42d51d6663f9fcdacfb2",          "chainId": 93        },        {          "address": "312769",          "chainId": 57        },        {          "address": null,          "chainId": 90        },        {          "address": "0x46dDa6a5a559d861c06EC9a95Fb395f5C3Db0742",          "chainId": 450        },        {          "address": "0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT",          "chainId": 99        },        {          "address": "0x01445c31581c354b7338ac35693ab2001b50b9ae",          "chainId": 33        },        {          "address": "0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e",          "chainId": 13        },        {          "address": "0xe936caa7f6d9f5c9e907111fcaf7c351c184cda7",          "chainId": 11        },        {          "address": "0xfe9f969faf8ad72a83b761138bf25de87eff9dd2",          "chainId": 426        },        {          "address": "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",          "chainId": 61        },        {          "address": "0x66e428c3f67a68878562e79a0234c1f83c208770",          "chainId": 75        },        {          "address": "0xEf213441a85DF4d7acBdAe0Cf78004E1e486BB96",          "chainId": 82        },        {          "address": "0x382bb369d343125bfb2117af9c149795c6c65c50",          "chainId": 45        },        {          "address": "0xbb06dca3ae6887fabf931640f67cab3e3a16f4dc",          "chainId": 17        },        {          "address": "0x4988a896b1227218e4a686fde5eabdcabd91571f",          "chainId": 31        },        {          "address": "0xdc19a122e268128b5ee20366299fc7b5b199c8e3",          "chainId": 85        },        {          "address": "secret18wpjn83dayu4meu6wnn29khfkwdxs7kyrz9c8f",          "chainId": 63        },        {          "address": "zil1sxx29cshups269ahh5qjffyr58mxjv9ft78jqy",          "chainId": 76        },        {          "address": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",          "chainId": 1        },        {          "address": "0xB75D0B03c06A926e488e2659DF1A861F860bD3d1",          "chainId": 157        },        {          "address": "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",          "chainId": 7        },        {          "address": "0xC0F4b3a52B0532Bf48784d2202C812B1841d8812",          "chainId": 411        },        {          "address": "0x17270E5364f226Cd5D77a16957c1b2663dC9699B",          "chainId": 382        },        {          "address": "0xf417F5A458eC102B90352F697D6e2Ac3A3d2851f",          "chainId": 143        },        {          "address": "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58",          "chainId": 84        },        {          "address": "0xefaeee334f0fd1712f9a8cc375f427d9cdd40d73",          "chainId": 52        },        {          "address": "0x55d398326f99059ff775485246999027b3197955",          "chainId": 4        },        {          "address": "0xfd36c336eb67a092dc80a063ff0644e13142d454",          "chainId": 152        },        {          "address": "e1d869a83212628ec82a4e039a95371a9ae4598c8459193ccfd0f2f2c689831f",          "chainId": 138        },        {          "address": "4Q89182juiadeFgGw3fupnrwnnDmBhf7e7fHWxnUP3S3",          "chainId": 137        },        {          "address": "0xfa9343c3897324496a05fc75abed6bac29f8a40f",          "chainId": 125        },        {          "address": "0x0cb6f5a34ad42ec934882a05265a7d5f59b51a2f",          "chainId": 97        },        {          "address": "usdt.tether-token.near",          "chainId": 29        },        {          "address": "32TLn1WLcu8LtfvweLzYUYU6ubc2YV9eZs",          "chainId": 38        },        {          "address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",          "chainId": 6        },        {          "address": "0xA510432E4aa60B4acd476fb850EC84B7EE226b2d",          "chainId": 469        },        {          "address": "0xc2c527c0cacf457746bd31b2a698fe89de2b6d49",          "chainId": 232        },        {          "address": "0x6a2d262D56735DbA19Dd70682B39F6bE9a931D98",          "chainId": 218        },        {          "address": "0xfA9343C3897324496A05fC75abeD6bAC29f8A40f",          "chainId": 217        },        {          "address": "0x9350502a3af6c617e9a42fa9e306a385::BX_USDT::BX_USDT",          "chainId": 215        },        {          "address": "ibc/4ABBEF4C8926DDDB320AE5188CFD63267ABBCEFC0583E4AE05D6E5AA2401DDAB",          "chainId": 141        },        {          "address": "0x381B31409e4D220919B2cFF012ED94d70135A59e",          "chainId": 48        },        {          "address": "0x4ECaBa5870353805a9F068101A40E0f32ed605C6",          "chainId": 78        },        {          "address": "0x0Cf7c2A584988871b654Bd79f96899e4cd6C41C0",          "chainId": 117        },        {          "address": "0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",          "chainId": 106        },        {          "address": "0x80a16016cc4a2e6a2caca8a4a498b1699ff0f844",          "chainId": 127        },        {          "address": "0xfe97E85d13ABD9c1c33384E796F10B73905637cE",          "chainId": 39        },        {          "address": "0xA219439258ca9da29E9Cc4cE5596924745e12B93",          "chainId": 101        },        {          "address": "0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df",          "chainId": 108        },        {          "address": "0x9e5aac1ba1a2e6aed6b32689dfcf62a509ca96f3",          "chainId": 110        },        {          "address": "0x988a631caf24e14bb77ee0f5ca881e8b5dcfcec7",          "chainId": 151        },        {          "address": "0xa3200696761a0cf122de2a679f745b3f8cfa2623",          "chainId": 155        },        {          "address": "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7",          "chainId": 147        },        {          "address": "A95EBDF88AC1E3FDECAA1D6E250B07C0C86475A3E2BFA2E7DC94A6CDE23DF6D6",          "chainId": 255        },        {          "address": "0x008D7923Fe2941Ceb549bf5646B1ddb1aC93C8a6",          "chainId": 408        },        {          "address": "0xefcAA73145B5e29eEfc47bcbaeFF9e870Fa6a610",          "chainId": 130        },        {          "address": "0x91Aa258324072dFf6F82408c2beB2F82D353b300",          "chainId": 131        },        {          "address": "0x3eee5d2ed0205f93969a59f7c8597fb614264436",          "chainId": 114        }      ]    },    {      "id": 72,      "slug": "kyber-network",      "symbol": "KNC",      "name": "Kyber Network Crystal ",      "priceUSD": "0.325609862550",      "volume24hUSD": "10125280.0251828828477000",      "circulatingSupply": "170152851",      "contracts": [        {          "address": "0x6ee46Cb7cD2f15Ee1ec9534cf29a5b51C83283e6",          "chainId": 96        },        {          "address": "0x6A80A465409ce8D36C513129C0FEEa61BEd579ba",          "chainId": 102        },        {          "address": "0x3b2F62d42DB19B30588648bf1c184865D4C3B1D6",          "chainId": 101        },        {          "address": "0x1e1085eFaA63EDFE74aaD7C05a28EAE4ef917C3F",          "chainId": 10        },        {          "address": "0x39fC9e94Caeacb435842FADeDeCB783589F50f5f",          "chainId": 7        },        {          "address": "0x316772cFEc9A3E976FDE42C3Ba21F5A13aAaFf12",          "chainId": 61        },        {          "address": "0xdeFA4e8a7bcBA345F687a2f1456F5Edd9CE97202",          "chainId": 3        },        {          "address": "0xfe56d5892bdffc7bf58f2e84be1b2c32d21c308b",          "chainId": 4        },        {          "address": "0x1c954e8fe737f99f68fa1ccda3e51ebdb291948c",          "chainId": 5        }      ]    },    {      "id": 1254,      "slug": "weth",      "symbol": "WETH",      "name": "WETH",      "priceUSD": "2523.982311036187",      "volume24hUSD": "1061921578.9958917235204746",      "circulatingSupply": "2652758",      "contracts": [        {          "address": "0:59b6b64ac6798aacf385ae9910008a525a84fc6dcf9f942ae81f8e8485fe160d",          "chainId": 93        },        {          "address": "0x2EAA73Bd0db20c64f53fEbeA7b5F5E5Bccc7fb8b",          "chainId": 48        },        {          "address": "0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::WETH",          "chainId": 91        },        {          "address": "0x722e8bdd2ce80a4422e880164f2079488e115365",          "chainId": 89        },        {          "address": "7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs",          "chainId": 1        },        {          "address": "0x2170Ed0880ac9A755fd29B2688956BD959F933F8",          "chainId": 4        },        {          "address": "0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea",          "chainId": 247        },        {          "address": "0xe44Fd7fCb2b1581822D0c862B68222998a0c299a",          "chainId": 75        },        {          "address": "0xab3f0245B83feB11d15AAffeFD7AD465a59817eD",          "chainId": 52        },        {          "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",          "chainId": 103        },        {          "address": "zil19j33tapjje2xzng7svslnsjjjgge930jx0w09v",          "chainId": 76        },        {          "address": "terra14tl83xcwqjy0ken9peu4pjjuu755lrry2uy25r",          "chainId": 2        },        {          "address": "0xc99a6a985ed2cac1ef41640596c5a5f9f4e19ef5",          "chainId": 34        },        {          "address": "0x02DcdD04e3F455D838cd1249292C58f3B79e3C3C",          "chainId": 97        },        {          "address": "0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB",          "chainId": 31        },        {          "address": "0x420000000000000000000000000000000000000A",          "chainId": 17        },        {          "address": "0x0258866edaf84d6081df17660357ab20a07d0c80",          "chainId": 43        },        {          "address": "0x135cb19acde9ffb4654cace4189a0e0fb4b6954e",          "chainId": 181        },        {          "address": "0x1540020a94aA8bc189aA97639Da213a4ca49d9a7",          "chainId": 18        },        {          "address": "0x4300000000000000000000000000000000000004",          "chainId": 221        },        {          "address": "0x7339e5586280dfa2b1f315827392ce414a44b1c0",          "chainId": 174        },        {          "address": "0x4200000000000000000000000000000000000006",          "chainId": 150        },        {          "address": "0x4200000000000000000000000000000000000006",          "chainId": 98        },        {          "address": "0xCD3f9D5Cbf51016e0d2340FE909E99C006422A48",          "chainId": 159        },        {          "address": "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f",          "chainId": 101        },        {          "address": "0xe7798f023fc62146e8aa1b36da45fb70855a77ea",          "chainId": 110        },        {          "address": "0x0Dc808adcE2099A9F62AA87D9670745AbA741746",          "chainId": 143        },        {          "address": "0x5300000000000000000000000000000000000004",          "chainId": 108        },        {          "address": "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",          "chainId": 5        },        {          "address": "0x8ed7d143Ef452316Ab1123d28Ab302dC3b80d3ce",          "chainId": 105        },        {          "address": "0x0ce35b0d42608ca54eb7bcc8044f7087c18e7717",          "chainId": 202        },        {          "address": "0x4200000000000000000000000000000000000006",          "chainId": 487        },        {          "address": "0x50c42dEAcD8Fc9773493ED674b675bE577f2634b",          "chainId": 465        },        {          "address": "0x3439153EB7AF838Ad19d56E1571FBD09333C2809",          "chainId": 489        },        {          "address": "0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590",          "chainId": 491        },        {          "address": "0xa722c13135930332Eb3d749B2F0906559D2C5b99",          "chainId": 47        },        {          "address": "0xf55af137a98607f7ed2efefa4cd2dfe70e4253b1",          "chainId": 71        },        {          "address": "0x5aea5775959fbc2557cc8789bc1bf90a239d9a91",          "chainId": 96        },        {          "address": "0xa47f43DE2f9623aCb395CA4905746496D2014d57",          "chainId": 39        },        {          "address": "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",          "chainId": 106        },        {          "address": "0x7EbeF2A4b1B09381Ec5B9dF8C5c6f2dBECA59c73",          "chainId": 128        },        {          "address": "85219708c49aa701871ad330a94ea0f41dff24ca",          "chainId": 33        },        {          "address": "0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d",          "chainId": 127        },        {          "address": "0x57eea49ec1087695274a9c4f341e414eb64328c2",          "chainId": 119        },        {          "address": "ibc/EA1D43981D5C9A1C4AAEA9C23BB1D4FA126BA9BC7020A25E0AE4AA841EA25DC5",          "chainId": null        },        {          "address": "0x695921034f0387eAc4e11620EE91b1b15A6A09fE",          "chainId": 10        },        {          "address": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",          "chainId": 61        },        {          "address": "THb4CqiFdwNHsWsQCs4JhzwjMWys4aqCbF",          "chainId": 6        },        {          "address": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",          "chainId": 3        },        {          "address": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",          "chainId": 3        },        {          "address": "0x122013fd7dF1C6F636a5bb8f03108E876548b455",          "chainId": 13        },        {          "address": "0x160345fC359604fC6e70E3c5fAcbdE5F7A9342d8",          "chainId": 157        },        {          "address": "0xfa9343c3897324496a05fc75abed6bac29f8a40f",          "chainId": 55        },        {          "address": "0x3223f17957Ba502cbe71401D55A0DB26E5F7c68F",          "chainId": 85        },        {          "address": "0x81ECac0D6Be0550A00FF064a4f9dd2400585FE9c",          "chainId": 83        },        {          "address": "0x6983d1e6def3690c4d616b13597a09e6193ea013",          "chainId": 12        },        {          "address": "0x6a023ccd1ff6f2045c3309768ead9e68f978f6e1",          "chainId": 78        },        {          "address": "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",          "chainId": 7        },        {          "address": "0x4200000000000000000000000000000000000006",          "chainId": 84        }      ]    },    {      "id": 1883,      "slug": "wrapped-bitcoin",      "symbol": "WBTC",      "name": "Wrapped Bitcoin",      "priceUSD": "104247.030463929140",      "volume24hUSD": "282269194.4261377519110420",      "circulatingSupply": "128815",      "contracts": [        {          "address": "EQDcBkGHmC4pTf34x3Gm05XvepO5w60DNxZ-XT4I6-UGG5L5",          "chainId": 95        },        {          "address": "0x0555E30da8f98308EdB960aa94C0Db47230d2B9c",          "chainId": 157        },        {          "address": "0x19df5689Cfce64bC2A55F7220B0Cd522659955EF",          "chainId": 450        },        {          "address": "0x3095c7557bcb296ccc6e363de01b760ba031f2d9",          "chainId": 12        },        {          "address": "0x8e5bbbb09ed1ebde8674cda39a0c169401db4252",          "chainId": 78        },        {          "address": "0:2ba32b75870d572e255809b7b423f30f36dd5dea075bd5f026863fceb81f2bcf",          "chainId": 93        },        {          "address": "0x68f180fcCe6836688e9084f035309E29Bf0A2095",          "chainId": 84        },        {          "address": "3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh",          "chainId": 1        },        {          "address": "io1c7unwg8h8vph89xwqru4f7zfa4yy5002wxvlrm",          "chainId": 43        },        {          "address": "0xF4eB217Ba2454613b15dBdea6e5f22276410e89e",          "chainId": 31        },        {          "address": "0xa5B55ab1dAF0F8e1EFc0eB1931a957fd89B918f4",          "chainId": 17        },        {          "address": "0x408d4cd0adb7cebd1f1a1c33a0ba2098e1295bab",          "chainId": 7        },        {          "address": "0x062E66477Faf219F25D27dCED647BF57C3107d52",          "chainId": 75        },        {          "address": "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",          "chainId": 3        },        {          "address": "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f",          "chainId": 61        },        {          "address": "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6",          "chainId": 5        },        {          "address": "0x313dbD8e65C6499dE939e5317cA97Ccc6eD4c621",          "chainId": 33        },        {          "address": "0xE57eBd2d67B462E9926e04a8e33f01cD0D64346D",          "chainId": 52        },        {          "address": "0xfa93c12cd345c658bc4644d1d4e1b9615952258c",          "chainId": 71        },        {          "address": "2260fac5e5542a773aa44fbcfedf7c193bc2c599.factory.bridge.near",          "chainId": 29        },        {          "address": "0x1f545487c62e5acfea45dcadd9c627361d1616d8",          "chainId": 39        },        {          "address": "8LQW8f7P5d5PZM7GtZEBgaqRPGSzS3DfPuiXrURJ4AJS",          "chainId": 69        },        {          "address": "0x927B51f251480a681271180DA4de28D44EC4AfB8",          "chainId": 492        },        {          "address": "0xcabae6f6ea1ecab08ad02fe02ce9a44f09aebfa2",          "chainId": 103        },        {          "address": "0xb17d901469b9208b17d916112988a3fed19b5ca1",          "chainId": 97        },        {          "address": "0xEA034fb02eB1808C2cc3adbC15f447B93CbE08e1",          "chainId": 102        },        {          "address": "zil1wha8mzaxhm22dpm5cav2tepuldnr8kwkvmqtjq",          "chainId": 76        },        {          "address": "0x3C1BCa5a656e69edCD0D4E36BEbb3FcDAcA60Cf1",          "chainId": 108        },        {          "address": "0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",          "chainId": 106        },        {          "address": "0xF6D226f9Dc15d9bB51182815b320D3fBE324e1bA",          "chainId": 220        },        {          "address": "0xbbeb516fb02a01611cbbe0453fe3c580d7281011",          "chainId": 96        },        {          "address": "0x027792d9fed7f9844eb4839566001bb6f6cb4804f66aa2da6fe1ee242d896881::coin::COIN",          "chainId": 99        },        {          "address": "0xcDd475325D6F564d27247D1DddBb0DAc6fA0a5CF",          "chainId": 150        },        {          "address": "0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4",          "chainId": 101        },        {          "address": "0x503b2ddc059b81788fd1239561596614b27faade",          "chainId": 48        },        {          "address": "0x0555E30da8f98308EdB960aa94C0Db47230d2B9c",          "chainId": 491        },        {          "address": "0xcb011e86df014a46f4e3ac3f3cbb114a4eb80870",          "chainId": 233        },        {          "address": "0xf390830df829cf22c53c8840554b98eafc5dcbc2",          "chainId": 55        },        {          "address": "0x78F811A431D248c1EDcF6d95ec8551879B2897C3",          "chainId": 11        }      ]    },    {      "id": 2854,      "slug": "venus",      "symbol": "XVS",      "name": "Venus",      "priceUSD": "5.882048680590",      "volume24hUSD": "2054331.9320935988631060",      "circulatingSupply": "16655176",      "contracts": [        {          "address": "0xd3CC9d8f3689B83c91b7B59cAB4946B063EB894A",          "chainId": 3        },        {          "address": "0xc1Eb7689147C81aC840d4FF0D298489fc7986d52",          "chainId": 61        },        {          "address": "0xcf6bb5389c92bdda8a3747ddb454cb7a64626c63",          "chainId": 4        },        {          "address": "0x3E2e61F1c075881F3fB8dd568043d8c221fd5c61",          "chainId": 110        },        {          "address": "0xD78ABD81a3D57712a3af080dc4185b698Fe9ac5A",          "chainId": 96        }      ]    },    {      "id": 5487,      "slug": "usdcoin",      "symbol": "USDC",      "name": "USDC",      "priceUSD": "0.999819756251",      "volume24hUSD": "5357299343.0449997080455914",      "circulatingSupply": "62369678914",      "contracts": [        {          "address": "0x81ECac0D6Be0550A00FF064a4f9dd2400585FE9c",          "chainId": 85        },        {          "address": "0x818ec0a7fe18ff94269904fced6ae3dae6d6dc0b",          "chainId": 52        },        {          "address": "0xe2c120f188ebd5389f71cf4d9c16d05b62a58993",          "chainId": 33        },        {          "address": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",          "chainId": 5        },        {          "address": "0x28a92dde19D9989F39A49905d7C9C2FAc7799bDf",          "chainId": 10        },        {          "address": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",          "chainId": 61        },        {          "address": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",          "chainId": 3        },        {          "address": "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",          "chainId": 99        },        {          "address": "0xc21223249ca28397b4b6541dffaecc539bff0c59",          "chainId": 75        },        {          "address": "0xceba9300f2b948710d2653dd7b07f33a8b32118c",          "chainId": 13        },        {          "address": "io18v4l9dfr74xyu320pz4zsmgrz9d07vnvy20yrh",          "chainId": 43        },        {          "address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",          "chainId": 1        },        {          "address": "secret1h6z05y90gwm4sqxzhz4pkyp36cna9xtp7q0urv",          "chainId": 63        },        {          "address": "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",          "chainId": 4        },        {          "address": "0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b",          "chainId": 91        },        {          "address": "0x980a5afef3d17ad98635f6c5aebcbaeded3c3430",          "chainId": 71        },        {          "address": "0x985458e523db3d53125813ed68c274899e9dfab4",          "chainId": 12        },        {          "address": "0x0b7007c13325c48911f73a2dad5fa5dcbf808adc",          "chainId": 34        },        {          "address": "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",          "chainId": 7        },        {          "address": "0x52a9cea01c4cbdd669883e41758b8eb8e8e2b34b",          "chainId": 44        },        {          "address": "0xc946daf81b08146b1c7a8da2a851ddf2b3eaaf85",          "chainId": 45        },        {          "address": "0x620fd5fa44be6af63715ef4e65ddfa0387ad13f5",          "chainId": 47        },        {          "address": "0xea32a96608495e54156ae48931a7c20f0dcc1a21",          "chainId": 17        },        {          "address": "31566704",          "chainId": 57        },        {          "address": "0x6d1e7cde53ba9467b783cb7c530ce054",          "chainId": 303        },        {          "address": "0x6a2d262d56735dba19dd70682b39f6be9a931d98",          "chainId": 90        },        {          "address": "0xB12BFcA5A55806AaF64E99521918A4bf0fC40802",          "chainId": 31        },        {          "address": "0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83",          "chainId": 78        },        {          "address": "0xcca4e6302510d555b654b3eab9c0fcb223bcfdf0",          "chainId": 48        },        {          "address": "TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8",          "chainId": 6        },        {          "address": "0x078D782b760474a361dDA0AF3839290b0EF57AD6",          "chainId": 492        },        {          "address": "USDC-c76f1f",          "chainId": 16        },        {          "address": "0x0b2c639c533813f4aa9d7837caf62653d097ff85",          "chainId": 84        },        {          "address": "0x275e916Ab1E93A6862a7b380751DdD87D6F66267",          "chainId": 371        },        {          "address": "0xd988097fb8612cc24eeC14542bC03424c656005f",          "chainId": 150        },        {          "address": "ibc/4A1C18CA7F50544760CF306189B810CE4C1CB156C7FC870143D401FE7280E591",          "chainId": 223        },        {          "address": "0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d",          "chainId": 168        },        {          "address": "0x80b5a32e4f032b2a058b4f29ec95eefeeb87adcd",          "chainId": 148        },        {          "address": "0xb73603C5d87fA094B7314C74ACE2e64D165016fb",          "chainId": 143        },        {          "address": "0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4",          "chainId": 108        },        {          "address": "ibc/D189335C6E4A68B513C10AB227BF1C1D38C746766278BA3EEB4FB14124F1D858",          "chainId": null        },        {          "address": "0x818ec0a7fe18ff94269904fced6ae3dae6d6dc0b",          "chainId": 55        },        {          "address": "0x00f0d8595797943c12605cd59bc0d9f63d750ccf",          "chainId": 119        },        {          "address": "0x540d90635a0C10CdD4D27fc8edCbf88c18DfB1eD",          "chainId": 116        },        {          "address": "0xE1aB220E37AC55A4E2dD5Ba148298A9c09fBD716",          "chainId": 183        },        {          "address": "0x640952e7984f2ecedead8fd97aa618ab1210a21c",          "chainId": 171        },        {          "address": "ibc/8E27BA2D5493AF5636760E354E46004562C46AB7EC0CC4C1CA14E9E20E2545B5",          "chainId": 250        },        {          "address": "17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1",          "chainId": 29        },        {          "address": "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4",          "chainId": 141        },        {          "address": "A.b19436aae4d94622.FiatToken",          "chainId": 68        },        {          "address": "0xfa9343c3897324496a05fc75abed6bac29f8a40f",          "chainId": 230        },        {          "address": "0xFFD7510ca0a3279c7a5F50018A26c21d5bc1DBcF",          "chainId": 107        },        {          "address": "0.0.456858",          "chainId": 94        },        {          "address": "0x09bc4e0d864854c6afb6eb9a9cdf58ac190d0df9",          "chainId": 103        },        {          "address": "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",          "chainId": 98        },        {          "address": "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",          "chainId": 106        },        {          "address": "1337",          "chainId": 54        },        {          "address": "USDC-GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",          "chainId": 66        },        {          "address": "e4b8164dccf3489f66124cace1570dc35b58fc90",          "chainId": 209        },        {          "address": "0xe2aa35C2039Bd0Ff196A6Ef99523CC0D3972ae3e",          "chainId": 198        },        {          "address": "0x3355df6d4c9c3035724fd0e3914de96a5a83aaf4",          "chainId": 96        },        {          "address": "0x6963EfED0aB40F6C3d7BdA44A05dcf1437C44372",          "chainId": 39        }      ]    },    {      "id": 7511,      "slug": "binance-usd",      "symbol": "BUSD",      "name": "BUSD",      "priceUSD": "0.999635670343",      "volume24hUSD": "2398317.6519931188988041",      "circulatingSupply": "57792684",      "contracts": [        {          "address": "0x4Fabb145d64652a948d72533023f6E7A623C7C53",          "chainId": 3        },        {          "address": "0x6ab6d61428fde76768d7b45d8bfeec19c6ef91a8",          "chainId": 75        },        {          "address": "0xe9e7cea3dedca5984780bafc599bd69add087d56",          "chainId": 4        },        {          "address": "0x19860ccb0a68fd4213ab9d8266f7bbf05a8dde98",          "chainId": 7        },        {          "address": "0x9c9e5fd8bbc25984b178fdce6117defa39d2db39",          "chainId": 84        },        {          "address": "0xa649325aa7c5093d12d6f98eb4378deae68ce23f",          "chainId": 52        },        {          "address": "0xc111c29a988ae0c0087d97b33c6e6766808a3bd3",          "chainId": 33        },        {          "address": "0x2039bb4116B4EFc145Ec4f0e2eA75012D6C0f181",          "chainId": 96        },        {          "address": "0x7d43AABC515C356145049227CeE54B608342c0ad",          "chainId": 101        },        {          "address": "0x5d9ab5522c64e1f6ef5e3627eccc093f56167818",          "chainId": 11        },        {          "address": "0x4bf769b05e832fcdc9053fffbc78ca889acb5e1e",          "chainId": 90        },        {          "address": "0xe176ebe47d621b984a73036b9da5d834411ef734",          "chainId": 12        },        {          "address": "0x332730a4f6e03d9c55829435f10360e13cfa41ff",          "chainId": 45        },        {          "address": "0x3444273afdf9e00fd0491c8a97738aca3ebb2a93",          "chainId": 18        },        {          "address": "0x4bf769b05e832fcdc9053fffbc78ca889acb5e1e",          "chainId": 83        },        {          "address": "0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39",          "chainId": 5        },        {          "address": "5RpUwQ8wtdPCZHhu6MERp2RGrpobsbZ6MH5dDHkUjs2",          "chainId": 1        },        {          "address": "0x84abcb2832be606341a50128aeb1db43aa017449",          "chainId": 43        },        {          "address": "0x7b37d0787a3424a0810e02b24743a45ebd5530b2",          "chainId": 74        }      ]    },    {      "id": 19793,      "slug": "multicollateraldai",      "symbol": "DAI",      "name": "Dai",      "priceUSD": "0.999911538842",      "volume24hUSD": "43665636.5443962007704738",      "circulatingSupply": "4015833934",      "contracts": [        {          "address": "0xef977d2f931c1978db5f6747666fa1eacb0d0339",          "chainId": 12        },        {          "address": "0x80a16016cc4a2e6a2caca8a4a498b1699ff0f844",          "chainId": 11        },        {          "address": "0x44fA8E6f47987339850636F88629646662444217",          "chainId": 78        },        {          "address": "terra1zmclyfepfmqvfqflu8r3lv6f75trmg05z7xq95",          "chainId": 2        },        {          "address": "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3",          "chainId": 4        },        {          "address": "0xf2001b145b43032aaf5ee2884e456ccd805f677d",          "chainId": 75        },        {          "address": "0x6b175474e89094c44da98b954eedeac495271d0f",          "chainId": 3        },        {          "address": "0xd586e7f844cea2f87f50152665bcbc2c279d8d70",          "chainId": 7        },        {          "address": "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063",          "chainId": 5        },        {          "address": "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb",          "chainId": 98        },        {          "address": "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",          "chainId": 89        },        {          "address": "0xcA77eB3fEFe3725Dc33bccB54eDEFc3D9f764f97",          "chainId": 108        },        {          "address": "0x0ee5893f434017d8881750101Ea2F7c49c0eb503",          "chainId": 107        },        {          "address": "0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3",          "chainId": 106        },        {          "address": "0x4C1f6fCBd233241bF2f4D02811E3bF8429BC27B8",          "chainId": 149        },        {          "address": "0x6cc8f0b5607e1f947e83667368881a1bccc3f1c4",          "chainId": 212        },        {          "address": "0xC5015b9d9161Dca7e18e32f6f25C4aD850731Fd4",          "chainId": 102        },        {          "address": "0x765277eebeca2e31912c9946eae1021199b39c61",          "chainId": 52        },        {          "address": "0x4b9eb6c0b6ea15176bbf62841c6b2a8a398cb656",          "chainId": 96        },        {          "address": "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",          "chainId": 61        },        {          "address": "0x0200060000000000000000000000000000000000000000000000000000000000",          "chainId": 24        },        {          "address": "0xe3520349f477a5f6eb06107066048508498a291b",          "chainId": 31        },        {          "address": "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",          "chainId": 84        },        {          "address": "0x6de33698e9e9b787e09d3bd7771ef63557e148bb",          "chainId": 90        },        {          "address": "0x4651b38e7ec14bb3db731369bfe5b08f2466bd0a",          "chainId": 17        },        {          "address": "EjmyN6qEC1Tf1JxiG1ae7UTJhUxSwk1TCWNWqxWV4J6o",          "chainId": 1        }      ]    },    {      "id": 21076,      "slug": "avalanche",      "symbol": "AVAX",      "name": "Avalanche",      "priceUSD": "20.463198322952",      "volume24hUSD": "234079380.7814911234932608",      "circulatingSupply": "421534916",      "contracts": [        {          "address": "0x2C89bbc92BD86F8075d1DEcc58C7F4E0107f286b",          "chainId": 5        },        {          "address": "0x1CE0c2827e2eF14D5C4f29a091d735A204794041",          "chainId": 4        },        {          "address": "0x4792c1ecb969b036eb51330c63bd27899a13d84e",          "chainId": 52        },        {          "address": "0xcd8fe44a29db9159db36f96570d7a4d91986f528",          "chainId": 19        },        {          "address": "0x14a0243C333A5b238143068dC3A7323Ba4C30ECB",          "chainId": 11        },        {          "address": "0x65e66a61D0a8F1e686C2D6083ad611a10D84D97A",          "chainId": 83        },        {          "address": "0x6a5279e99ca7786fb13f827fc1fb4f61684933d6",          "chainId": 96        }      ]    },    {      "id": 23000,      "slug": "pancakeswap",      "symbol": "CAKE",      "name": "PancakeSwap",      "priceUSD": "2.371277962566",      "volume24hUSD": "82354494.6215425524394026",      "circulatingSupply": "321554264",      "contracts": [        {          "address": "0x0D1E753a25eBda689453309112904807625bEFBe",          "chainId": 101        },        {          "address": "0x3A287a06c66f9E95a56327185cA2BDF5f031cEcD",          "chainId": 96        },        {          "address": "0x1b896893dfc86bb67Cf57767298b9073D2c1bA2c",          "chainId": 61        },        {          "address": "0x2779106e4F4A8A28d77A24c18283651a2AE22D1C",          "chainId": 110        },        {          "address": "0x0d1e753a25ebda689453309112904807625befbe",          "chainId": 102        },        {          "address": "0x3055913c90Fcc1A6CE9a358911721eEb942013A1",          "chainId": 98        },        {          "address": "0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898",          "chainId": 3        },        {          "address": "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82",          "chainId": 4        },        {          "address": "0x159df6b7689437016108a019fd5bef736bac692b6d4a1f10c941f6fbb9a74ca6::oft::CakeOFT",          "chainId": 91        }      ]    },    {      "id": 25225,      "slug": "dextf-protocol",      "symbol": "DEXTF",      "name": "Domani Protocol",      "priceUSD": "0.144790927447",      "volume24hUSD": "134748.9592184632356044",      "circulatingSupply": "65807235",      "contracts": [        {          "address": "0x9929bcac4417a21d7e6fc86f6dae1cc7f27a2e41",          "chainId": 96        },        {          "address": "0x03E8D118A1864c7Dc53bf91e007ab7D91f5A06fA",          "chainId": 7        },        {          "address": "0x5F64Ab1544D28732F0A24F4713c2C8ec0dA089f0",          "chainId": 3        }      ]    },    {      "id": 25781,      "slug": "wbnb",      "symbol": "WBNB",      "name": "Wrapped BNB",      "priceUSD": "656.079994507931",      "volume24hUSD": "2292132064.2050728573560094",      "circulatingSupply": "1523844",      "contracts": [        {          "address": "0xfa9343c3897324496a05fc75abed6bac29f8a40f",          "chainId": 75        },        {          "address": "0x442F7f22b1EE2c842bEAFf52880d4573E9201158",          "chainId": 7        },        {          "address": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",          "chainId": 4        },        {          "address": "0xc9baa8cfdde8e328787e29b4b078abf2dadc2055",          "chainId": 52        },        {          "address": "0x7f27352D5F83Db87a5A3E00f4B07Cc2138D8ee52",          "chainId": 83        },        {          "address": "9gP2kCy3wA1ctvYWQk75guqXuHfrEomqydHLtcTCqiLa",          "chainId": 1        },        {          "address": "0x673d2ec54e0a6580fc7e098295b70e3ce0350d03",          "chainId": 12        },        {          "address": "0x7400793aad94c8ca801aa036357d10f5fd0ce08f",          "chainId": 96        },        {          "address": "0xeCDCB5B88F8e3C15f95c720C51c71c9E2080525d",          "chainId": 5        },        {          "address": "0xd7D045BFBa6Ea93b480F409DB3dd1729337C1d13",          "chainId": 18        },        {          "address": "0x97e6c48867fdc391a8dfe9d169ecd005d1d90283",          "chainId": 43        },        {          "address": "0x2bF9b864cdc97b08B6D79ad4663e71B8aB65c45c",          "chainId": 31        },        {          "address": "0x2c78f1b70ccf63cdee49f9233e9faa99d43aa07e",          "chainId": 55        },        {          "address": "terra1cetg5wruw2wsdjp7j46rj44xdel00z006e9yg8",          "chainId": 2        },        {          "address": "ibc/F4A070A6D78496D53127EA85C094A9EC87DFC1F36071B8CCDDBD020F933D213D",          "chainId": null        },        {          "address": "0xf5c6825015280cdfd0b56903f9f8b5a2233476f5",          "chainId": 101        },        {          "address": "0x94bd7A37d2cE24cC597E158fACaa8d601083ffeC",          "chainId": 39        },        {          "address": "0xb848cce11ef3a8f62eccea6eb5b35a12c4c2b1ee1af7755d02d7bd6218e8226f::coin::COIN",          "chainId": 99        },        {          "address": "0xD67de0e0a0Fd7b15dC8348Bb9BE742F3c5850454",          "chainId": 10        },        {          "address": "0x418D75f65a02b3D53B2418FB8E1fe493759c7605",          "chainId": 3        }      ]    },    {      "id": 26062,      "slug": "wootrade",      "symbol": "WOO",      "name": "WOO",      "priceUSD": "0.075585907922",      "volume24hUSD": "3381083.3045858390631228",      "circulatingSupply": "1918868005",      "contracts": [        {          "address": "0xabc9547b534519ff73921b1fba6e672b5f58d083",          "chainId": 7        },        {          "address": "0x6626c47c00f1d87902fc13eecfac3ed06d5e8d8a",          "chainId": 10        },        {          "address": "0x4691937a7508860f876c9c0a2a617e7d9e945d4b",          "chainId": 4        },        {          "address": "0x3befb2308bce92da97264077faf37dcd6c8a75e6",          "chainId": 14        },        {          "address": "0x1B815d120B3eF02039Ee11dC2d33DE7aA4a8C603",          "chainId": 5        },        {          "address": "0x4691937a7508860f876c9c0a2a617e7d9e945d4b",          "chainId": 3        },        {          "address": "0xcafcd85d8ca7ad1e1c6f82f651fa15e33aefd07b",          "chainId": 61        },        {          "address": "E5rk3nmgLUuKUiS94gg4bpWwWwyjCMtddsAXkTFLtHEy",          "chainId": 1        },        {          "address": "4691937a7508860f876c9c0a2a617e7d9e945d4b.factory.bridge.near",          "chainId": 29        },        {          "address": "0x9E22D758629761FC5708c171d06c2faBB60B5159",          "chainId": 96        }      ]    },    {      "id": 28986,      "slug": "govi",      "symbol": "GOVI",      "name": "CVI",      "priceUSD": "0.014434503875",      "volume24hUSD": "84854.0413822350425000",      "circulatingSupply": "15439655",      "contracts": [        {          "address": "0xeeaa40b28a2d1b0b08f6f97bb1dd4b75316c6107",          "chainId": 3        },        {          "address": "0x43Df9c0a1156c96cEa98737b511ac89D0e2A1F46",          "chainId": 5        },        {          "address": "0x07e49d5de43dda6162fa28d24d5935c151875283",          "chainId": 61        },        {          "address": "0xD63eF5e9C628c8a0E8984CDfb7444AEE44B09044",          "chainId": 96        }      ]    },    {      "id": 29494,      "slug": "mute",      "symbol": "MUTE",      "name": "Mute",      "priceUSD": "0.016605279624",      "volume24hUSD": "4.6335687763122456",      "circulatingSupply": "40000000",      "contracts": [        {          "address": "0xa49d7499271ae71cd8ab9ac515e6694c755d400c",          "chainId": 3        },        {          "address": "0x0e97c7a0f8b2c9885c8ac9fc6136e829cbc21d42",          "chainId": 96        }      ]    },    {      "id": 78303,      "slug": "wpol",      "symbol": "WPOL",      "name": "Wrapped POL",      "priceUSD": "0.214828338580",      "volume24hUSD": "7167694.6332244566141460",      "circulatingSupply": "298839976",      "contracts": [        {          "address": "0xf2f13f0B7008ab2FA4A2418F4ccC3684E49D20Eb",          "chainId": 7        },        {          "address": "0xc836d8dC361E44DbE64c4862D55BA041F88Ddd39",          "chainId": 4        },        {          "address": "0x28a487240e4d45cff4a2980d334cc933b7483842",          "chainId": 96        },        {          "address": "0xdbe380b13a6d0f5cdedd58de8f04625263f113b3f9db32b3e1983f49e2841676::coin::COIN",          "chainId": 99        },        {          "address": "Gz7VkD4MacbEB6yC5XD3HcumEiYx2EtDYYrfikGsvopG",          "chainId": 1        },        {          "address": "0x6aB6d61428fde76768D7b45D8BFeec19c6eF91A8",          "chainId": 31        },        {          "address": "0x8e66c0d6b70c0b23d39f4b21a1eac52bba8ed89a",          "chainId": 43        },        {          "address": "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",          "chainId": 5        }      ]    },    {      "id": 169625,      "slug": "idexo-token",      "symbol": "IDO",      "name": "Idexo Token",      "priceUSD": "0.019806179953",      "volume24hUSD": "28219.3104301756690000",      "circulatingSupply": "81027500",      "contracts": [        {          "address": "0xF9c53268e9de692AE1b2ea5216E24e1c3ad7CB1E",          "chainId": 3        },        {          "address": "0xDea6d5161978d36b5C0FA6a491faA754f4BC809C",          "chainId": 96        }      ]    },    {      "id": 169760,      "slug": "lido-finance-wsteth",      "symbol": "wstETH",      "name": "Wrapped stETH",      "priceUSD": "3038.168722518680",      "volume24hUSD": "6334397.0657931186642560",      "circulatingSupply": "3545482",      "contracts": [        {          "address": "0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb",          "chainId": 84        },        {          "address": "0xf610A9dfB7C89644979b4A0f27063E9e7d7Cda32",          "chainId": 108        },        {          "address": "0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6",          "chainId": 78        },        {          "address": "0x703b52f2b28febcb60e1372858af5b18849fe867",          "chainId": 96        },        {          "address": "0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F",          "chainId": 101        },        {          "address": "0x458ed78EB972a369799fb278c0243b25e5242A83",          "chainId": 103        },        {          "address": "0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452",          "chainId": 98        },        {          "address": "0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD",          "chainId": 5        },        {          "address": "0xc02fE7317D4eb8753a02c35fe019786854A92001",          "chainId": 492        },        {          "address": "0x5979D7b546E38E414F7E9822514be443A4800529",          "chainId": 61        },        {          "address": "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",          "chainId": 3        }      ]    },    {      "id": 169918,      "slug": "nodle",      "symbol": "NODL",      "name": "Nodle",      "priceUSD": "0.000305023780",      "volume24hUSD": "116874.9633574116394000",      "circulatingSupply": "935521185",      "contracts": [        {          "address": "0xBD4372e44c5eE654dd838304006E1f0f69983154",          "chainId": 96        }      ]    },    {      "id": 171109,      "slug": "symbiosis-finance",      "symbol": "SIS",      "name": "Symbiosis Finance",      "priceUSD": "0.060961263279",      "volume24hUSD": "1632923.5396401369641178",      "circulatingSupply": "65321769",      "contracts": [        {          "address": "0x1467b62A6AE5CdcB10A6a8173cfe187DD2C5a136",          "chainId": 108        },        {          "address": "0x9e758b8a98a42d612b3d38b66a22074dc03d7370",          "chainId": 61        },        {          "address": "0x6EF95B6f3b0F39508e3E04054Be96D5eE39eDE0d",          "chainId": 101        },        {          "address": "0xd38bb40815d2b0c2d2c866e0c72c5728ffc76dd9",          "chainId": 3        },        {          "address": "0xdd9f72afED3631a6C85b5369D84875e6c42f1827",          "chainId": 96        },        {          "address": "0xF98b660AdF2ed7d9d9D9dAACC2fb0CAce4F21835",          "chainId": 4        }      ]    },    {      "id": 171673,      "slug": "izumi-finance",      "symbol": "IZI",      "name": "iZUMi Finance",      "priceUSD": "0.004412784502",      "volume24hUSD": "330746.6003961574641634",      "circulatingSupply": "787400000",      "contracts": [        {          "address": "0x9ad37205d608B8b219e6a2573f922094CEc5c200",          "chainId": 3        },        {          "address": "0x60D01EC2D5E98Ac51C8B4cF84DfCCE98D527c747",          "chainId": 61        },        {          "address": "0x60D01EC2D5E98Ac51C8B4cF84DfCCE98D527c747",          "chainId": 108        },        {          "address": "0x16A9494e257703797D747540f01683952547EE5b",          "chainId": 96        },        {          "address": "0x60d01ec2d5e98ac51c8b4cf84dfcce98d527c747",          "chainId": 103        },        {          "address": null,          "chainId": 4        },        {          "address": "0x60D01EC2D5E98Ac51C8B4cF84DfCCE98D527c747",          "chainId": 98        },        {          "address": "0x91647632245cabf3d66121f86c387ae0ad295f9a",          "chainId": 143        },        {          "address": "0x60D01EC2D5E98Ac51C8B4cF84DfCCE98D527c747",          "chainId": 101        },        {          "address": "0x60D01EC2D5E98Ac51C8B4cF84DfCCE98D527c747",          "chainId": 5        }      ]    },    {      "id": 173442,      "slug": "liquity-usd",      "symbol": "LUSD",      "name": "Liquity USD",      "priceUSD": "0.995979718780",      "volume24hUSD": "2758.7340448632429660",      "circulatingSupply": "41318766",      "contracts": [        {          "address": "0x368181499736d0c0CC614DBB145E2EC1AC86b8c6",          "chainId": 98        },        {          "address": "0xc40F949F8a4e094D1b49a23ea9241D289B7b2819",          "chainId": 84        },        {          "address": "0x5f98805a4e8be255a32880fdec7f6728c6568ba0",          "chainId": 3        },        {          "address": "0x93b346b6BC2548dA6A1E7d98E9a421B42541425b",          "chainId": 61        },        {          "address": "0x503234F203fC7Eb888EEC8513210612a43Cf6115",          "chainId": 96        },        {          "address": "0x23001f892c0c82b79303edc9b9033cd190bb21c7",          "chainId": 5        }      ]    },    {      "id": 174671,      "slug": "maverick-protocol",      "symbol": "MAV",      "name": "Maverick Protocol",      "priceUSD": "0.055832135906",      "volume24hUSD": "2049518.9217414230150462",      "circulatingSupply": "603700522",      "contracts": [        {          "address": "0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD",          "chainId": 3        },        {          "address": "0x64b88c73A5DfA78D1713fE1b4c69a22d7E0faAa7",          "chainId": 98        },        {          "address": "0x787c09494Ec8Bcb24DcAf8659E7d5D69979eE508",          "chainId": 96        },        {          "address": "0xd691d9a68C887BDF34DA8c36f63487333ACfD103",          "chainId": 4        }      ]    },    {      "id": 174835,      "slug": "usd",      "symbol": "USD+",      "name": "Overnight.fi USD+",      "priceUSD": "1.000886021354",      "volume24hUSD": "2318557.5607744404448812",      "circulatingSupply": "85659194",      "contracts": [        {          "address": "0x236eeC6359fb44CCe8f97E99387aa7F8cd5cdE1f",          "chainId": 5        },        {          "address": "0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376",          "chainId": 101        },        {          "address": "0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376",          "chainId": 98        },        {          "address": "0x4fEE793d435c6D2c10C135983BB9d6D4fC7B9BBd",          "chainId": 221        },        {          "address": "0xe80772eaf6e2e18b651f160bc9158b2a5cafca65",          "chainId": 61        },        {          "address": "0xe80772eaf6e2e18b651f160bc9158b2a5cafca65",          "chainId": 7        },        {          "address": "0x8E86e46278518EFc1C5CEd245cBA2C7e3ef11557",          "chainId": 96        },        {          "address": "0x73cb180bf0521828d8849bc8cf2b920918e23032",          "chainId": 84        },        {          "address": "0xe80772eaf6e2e18b651f160bc9158b2a5cafca65",          "chainId": 4        }      ]    },    {      "id": 176076,      "slug": "zksync",      "symbol": "ZK",      "name": "zkSync",      "priceUSD": "0.053223305221",      "volume24hUSD": "21534018.8609259087161898",      "circulatingSupply": "3675000000",      "contracts": [        {          "address": "0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E",          "chainId": 96        }      ]    },    {      "id": 177999,      "slug": "metavault-trade",      "symbol": "MVX",      "name": "Metavault Trade",      "priceUSD": "0.134441948770",      "volume24hUSD": "55.7786201251853000",      "circulatingSupply": "3158978",      "contracts": [        {          "address": "0x0018D96C579121a94307249d47F053E2D687b5e7",          "chainId": 101        },        {          "address": "0x0018D96C579121a94307249d47F053E2D687b5e7",          "chainId": 108        },        {          "address": "0xc8ac6191cdc9c7bf846ad6b52aaaa7a0757ee305",          "chainId": 96        },        {          "address": "0x2760e46d9bb43dafcbecaad1f64b93207f9f0ed7",          "chainId": 5        }      ]    },    {      "id": 178476,      "slug": "paxo-finance",      "symbol": "WEFI",      "name": "WeFi",      "priceUSD": "0.030589544594",      "volume24hUSD": "6155.0057772154816200",      "circulatingSupply": "41883332",      "contracts": [        {          "address": "0xfFA188493C15DfAf2C206c97D8633377847b6a52",          "chainId": 5        },        {          "address": "0x81E7186947fb59AAAAEb476a47daAc60680cbbaF",          "chainId": 96        },        {          "address": "0x60892e742d91d16Be2cB0ffE847e85445989e30B",          "chainId": 101        },        {          "address": "0xfFA188493C15DfAf2C206c97D8633377847b6a52",          "chainId": 4        },        {          "address": "0xfFA188493C15DfAf2C206c97D8633377847b6a52",          "chainId": 61        },        {          "address": "0xfFA188493C15DfAf2C206c97D8633377847b6a52",          "chainId": 3        }      ]    },    {      "id": 180336,      "slug": "veno-finance",      "symbol": "VNO",      "name": "Veno Finance",      "priceUSD": "0.018190374275",      "volume24hUSD": "115437.6067161836517400",      "circulatingSupply": "511160922",      "contracts": [        {          "address": "0xe75a17b4f5c4f844688d5670b684515d7c785e63",          "chainId": 96        },        {          "address": "0xdb7d0a1ec37de1de924f8e8adac6ed338d4404e9",          "chainId": 75        }      ]    },    {      "id": 181064,      "slug": "hypercomic",      "symbol": "HYCO",      "name": "HYPERCOMIC",      "priceUSD": "0.000056327575",      "volume24hUSD": "94095.2908919698815000",      "circulatingSupply": null,      "contracts": [        {          "address": "0x77F76483399Dc6328456105B1db23e2Aca455bf9",          "chainId": 3        },        {          "address": "0x45656c02Aae856443717C34159870b90D1288203",          "chainId": 96        }      ]    },    {      "id": 181939,      "slug": "zkdoge",      "symbol": "ZKDOGE",      "name": "zkDoge",      "priceUSD": "0.000003460380",      "volume24hUSD": "9.8128693700984100",      "circulatingSupply": null,      "contracts": [        {          "address": "0xbFB4b5616044Eded03e5b1AD75141f0D9Cb1499b",          "chainId": 96        }      ]    },    {      "id": 181986,      "slug": "fulcrom-finance",      "symbol": "FUL",      "name": "Fulcrom",      "priceUSD": "0.006995472668",      "volume24hUSD": "15865.7646197202946152",      "circulatingSupply": "2097500155",      "contracts": [        {          "address": "0xe593853b4d603d5b8f21036Bb4AD0D1880097a6e",          "chainId": 96        },        {          "address": "0x83aFB1C32E5637ACd0a452D87c3249f4a9F0013A",          "chainId": 75        }      ]    },    {      "id": 182038,      "slug": "space-fi",      "symbol": "SPACE",      "name": "SpaceFi",      "priceUSD": "0.008479370310",      "volume24hUSD": "273.3965067737609730",      "circulatingSupply": "7047643",      "contracts": [        {          "address": "0x47260090ce5e83454d5f05a0abbb2c953835f777",          "chainId": 96        }      ]    },    {      "id": 182572,      "slug": "reactorfusion",      "symbol": "RF",      "name": "ReactorFusion",      "priceUSD": "0.001274750675",      "volume24hUSD": null,      "circulatingSupply": null,      "contracts": [        {          "address": "0x5f7CBcb391d33988DAD74D6Fd683AadDA1123E4D",          "chainId": 96        }      ]    },    {      "id": 182821,      "slug": "derp-coin",      "symbol": "DERP",      "name": "DerpDEX",      "priceUSD": "0.000000000982",      "volume24hUSD": "86527.3838211341400000",      "circulatingSupply": "55600000000000",      "contracts": [        {          "address": "0x5DfC78C4D073fD343BC6661668948178522A0DE5",          "chainId": 3        },        {          "address": "0x0bf4CB727b3f8092534D793893B2cC3348963dbf",          "chainId": 96        },        {          "address": "0xEbb78043e29F4af24E6266A7D142f5A08443969E",          "chainId": 98        },        {          "address": "0xEbb78043e29F4af24E6266A7D142f5A08443969E",          "chainId": 110        }      ]    },    {      "id": 183061,      "slug": "zkapes",      "symbol": "ZAT",      "name": "zkApe",      "priceUSD": "0.000000002068",      "volume24hUSD": "84267.4172353719200000",      "circulatingSupply": "46426356238082",      "contracts": [        {          "address": "0x47EF4A5641992A72CFd57b9406c9D9cefEE8e0C4",          "chainId": 96        }      ]    },    {      "id": 183169,      "slug": "vesync",      "symbol": "VS",      "name": "veSync",      "priceUSD": "0.000177133079",      "volume24hUSD": "17.5539080563713875",      "circulatingSupply": null,      "contracts": [        {          "address": "0x5756A28E2aAe01F600FC2C01358395F5C1f8ad3A",          "chainId": 96        }      ]    },    {      "id": 183206,      "slug": "gravita-protocol",      "symbol": "GRAI",      "name": "Gravita Protocol",      "priceUSD": "1.038124398700",      "volume24hUSD": "254.4263305692724900",      "circulatingSupply": "115838",      "contracts": [        {          "address": "0x15f74458aE0bFdAA1a96CA1aa779D715Cc1Eefe4",          "chainId": 3        },        {          "address": "0x894134a25a5faC1c2C26F1d8fBf05111a3CB9487",          "chainId": 61        },        {          "address": "0x5fc44e95eaa48f9eb84be17bd3ac66b6a82af709",          "chainId": 96        }      ]    },    {      "id": 185576,      "slug": "holdstation",      "symbol": "HOLD",      "name": "Holdstation",      "priceUSD": "1.047597992039",      "volume24hUSD": "566623.5207217100563030",      "circulatingSupply": "7903700",      "contracts": [        {          "address": "0xed4040fd47629e7c8fbb7da76bb50b3e7695f0f2",          "chainId": 96        }      ]    },    {      "id": 185628,      "slug": "metaelfland-new",      "symbol": "MELD",      "name": "MetaElfLand",      "priceUSD": "0.000085906805",      "volume24hUSD": "104532.7469887663634000",      "circulatingSupply": "549580000",      "contracts": [        {          "address": "0xcd2cfa60f04f3421656d6eebee122b3973b3f60c",          "chainId": 96        }      ]    },    {      "id": 185653,      "slug": "karat",      "symbol": "KAT",      "name": "Karat",      "priceUSD": "0.000561575224",      "volume24hUSD": "65780.8531208648736000",      "circulatingSupply": "1090715670",      "contracts": [        {          "address": "0xCDb7D260c107499C80B4b748e8331c64595972a1",          "chainId": 96        }      ]    },    {      "id": 185915,      "slug": "zkswap-finance",      "symbol": "ZF",      "name": "zkSwap Finance",      "priceUSD": "0.002617039976",      "volume24hUSD": "140497.8235385651772904",      "circulatingSupply": "551289480",      "contracts": [        {          "address": "0x31c2c031fdc9d33e974f327ab0d9883eae06ca4a",          "chainId": 96        }      ]    },    {      "id": 186051,      "slug": "wagmi-com",      "symbol": "WAGMI",      "name": "Wagmi",      "priceUSD": "0.006931617803",      "volume24hUSD": "1934561.2104832143165772",      "circulatingSupply": "1816532138",      "contracts": [        {          "address": "0xaf20f5f19698f1D19351028cd7103B63D30DE7d7",          "chainId": 4        },        {          "address": "0xb1f795776cb9ddac6e7e162f31c7419dd3d48297",          "chainId": 10        },        {          "address": "0xaf20f5f19698f1d19351028cd7103b63d30de7d7",          "chainId": 61        },        {          "address": "0x07Ed33a242BD9C08CA3C198e01189e35265024Da",          "chainId": 5        },        {          "address": "0x92CC36D66e9d739D50673d1f27929a371FB83a67",          "chainId": 3        },        {          "address": "0xaf20f5f19698f1d19351028cd7103b63d30de7d7",          "chainId": 7        },        {          "address": "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B",          "chainId": 465        },        {          "address": "0xaf20f5f19698f1D19351028cd7103B63D30DE7d7",          "chainId": 314        },        {          "address": "0xaf20f5f19698f1D19351028cd7103B63D30DE7d7",          "chainId": 98        },        {          "address": "0xaf20f5f19698f1d19351028cd7103b63d30de7d7",          "chainId": 84        },        {          "address": "0xaf20f5f19698f1d19351028cd7103b63d30de7d7",          "chainId": 17        },        {          "address": "0x3613ad277df1d5935d41400a181aa9ec1dc2dc9e",          "chainId": 96        }      ]    },    {      "id": 187519,      "slug": "tarot-v-2",      "symbol": "TAROT",      "name": "Tarot v2",      "priceUSD": "0.102369568487",      "volume24hUSD": "26514.2841985293372282",      "circulatingSupply": "67508541",      "contracts": [        {          "address": "0xf544251d25f3d243a36b07e7e7962a678f952691",          "chainId": 98        },        {          "address": "0x7f2fd959013eec5144269ac6edd0015cb10968fc",          "chainId": 96        },        {          "address": "0x2e4c7bf66d0484e44fea0ec273b85a00af92b2e3",          "chainId": 81        },        {          "address": "0x981bd9f77c8aafc14ebc86769503f86a3cc29af5",          "chainId": 103        },        {          "address": "0x13278cd824d33a7adb9f0a9a84aca7c0d2deebf7",          "chainId": 89        },        {          "address": "0xb092e1bf50f518b3ebf7ed26a40015183ae36ac2",          "chainId": 5        },        {          "address": "0x5ecfec22aa950cb5a3b4fd7249dc30b2bd160f18",          "chainId": 7        },        {          "address": "0x1f514a61bcde34f94bc39731235690ab9da737f7",          "chainId": 84        },        {          "address": "0x982e609643794a31a07f5c5b142dd3a9cf0690be",          "chainId": 4        },        {          "address": "0xa10bf0aba0c7953f279c4cb8192d3b5de5ea56e8",          "chainId": 3        },        {          "address": "0xb7c2ddb1ebac1056231ef22c1b0a13988537a274",          "chainId": 10        }      ]    },    {      "id": 187575,      "slug": "zero-lend",      "symbol": "ZERO",      "name": "ZeroLend",      "priceUSD": "0.000055572630",      "volume24hUSD": "1902730.6709149503654030",      "circulatingSupply": "71671379638",      "contracts": [        {          "address": "0x78354f8dccb269a615a7e0a24f9b0718fdc3c7a7",          "chainId": 101        },        {          "address": "0x27d0A2b5316b98088294378692F4EAbfB3222e36",          "chainId": 96        }      ]    },    {      "id": 188057,      "slug": "libertas-omnibus",      "symbol": "LIBERTAS",      "name": "LIBERTAS OMNIBUS",      "priceUSD": "2.012875893051",      "volume24hUSD": "18.4928946922274523",      "circulatingSupply": null,      "contracts": [        {          "address": "0xC6DaC3A53D5d6dE9D1D05AA6e28B8e9E41722601",          "chainId": 96        }      ]    },    {      "id": 188523,      "slug": "koi-2",      "symbol": "KOI",      "name": "Koi",      "priceUSD": "0.002194806500",      "volume24hUSD": "205.9992931609069500",      "circulatingSupply": "500000000",      "contracts": [        {          "address": "0xa995ad25ce5eb76972ab356168f5e1d9257e4d05",          "chainId": 96        },        {          "address": "0x9d14bce1daddf408d77295bb1be9b343814f44de",          "chainId": 3        }      ]    },    {      "id": 188734,      "slug": "autoair-ai",      "symbol": "AAI",      "name": "AutoAir AI",      "priceUSD": "0.002541865297",      "volume24hUSD": null,      "circulatingSupply": "33250000",      "contracts": [        {          "address": "0x144b83555d8a3119b0a69a7bc2f0a0388308fee3",          "chainId": 96        }      ]    },    {      "id": 189041,      "slug": "long-2",      "symbol": "LONG",      "name": "Long",      "priceUSD": "0.000000694095",      "volume24hUSD": "0.8418805348653165",      "circulatingSupply": "783813835230",      "contracts": [        {          "address": "0x5165ec33b491d7b67260B3143f96Bb4aC4736398",          "chainId": 96        }      ]    },    {      "id": 189524,      "slug": "tevaera-zk",      "symbol": "TEVA",      "name": "Tevaera",      "priceUSD": "0.007110085092",      "volume24hUSD": "859877.3327826079846800",      "circulatingSupply": "425508223",      "contracts": [        {          "address": "0xdbFF7c6d368904680706804645cAfA4dEfa3c224",          "chainId": 96        }      ]    },    {      "id": 189990,      "slug": "wrapped-rseth",      "symbol": "wrsETH",      "name": "Wrapped rsETH",      "priceUSD": "2642.703746000547",      "volume24hUSD": "47011.5854783529306924",      "circulatingSupply": null,      "contracts": [        {          "address": "0x87eEE96D50Fb761AD85B1c982d28A042169d61b1",          "chainId": 84        },        {          "address": "0xD2671165570f41BBB3B0097893300b6EB6101E6C",          "chainId": 101        },        {          "address": "0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd",          "chainId": 150        },        {          "address": "0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd",          "chainId": 221        },        {          "address": "0xEDfa23602D0EC14714057867A78d01e94176BEA0",          "chainId": 98        },        {          "address": "0xd4169E045bcF9a86cC00101225d9ED61D2F51af2",          "chainId": 96        },        {          "address": "0xa25b25548B4C98B0c7d3d27dcA5D5ca743d68b7F",          "chainId": 108        }      ]    }  ],  "meta": {    "count": 52  },  "status": {    "time": "2025-06-02T14:54:40.534Z",    "success": true,    "code": 200,    "message": "OK",    "responseTime": 12,    "creditsCost": 1  }}
    """
  end

  defp json_tokens_2nd_page do
    """
    {"data":[{"id":190444,"slug":"zyfi","symbol":"ZFI","name":"Zyfi","priceUSD":"0.004467522847","volume24hUSD":"527.5318580293320804","circulatingSupply":"228225560","contracts":[{"address":"0x5d0d7BCa050e2E98Fd4A5e8d3bA823B49f39868d","chainId":96}]},{"id":193174,"slug":"heurist","symbol":"HEU","name":"Heurist","priceUSD":"0.019624517115","volume24hUSD":"214644.7428230154531300","circulatingSupply":"155241424","contracts":[{"address":"0xEF22cb48B8483dF6152e1423b19dF5553BbD818b","chainId":98},{"address":"0xAbEc5eCBe08b6c02F5c9A2fF82696e1E7dB6f9bf","chainId":96}]}],"meta":{"count":52},"status":{"time":"2025-06-02T15:11:56.798Z","success":true,"code":200,"message":"OK","responseTime":11,"creditsCost":1}}
    """
  end

  # cspell:enable

  defp json_native_coin_history do
    """
    {"data":{"dates":["2025-05-28T00:00:00.000Z","2025-05-29T00:00:00.000Z","2025-05-30T00:00:00.000Z","2025-05-31T00:00:00.000Z","2025-06-01T00:00:00.000Z"],"volumes":[10438545595.534193,7970411497.8339,11568734237.80682,10646850181.382534,5666095954.980677],"prices":[2662.609005038795,2681.794582393094,2631.742984069461,2532.024768716731,2528.507007933771],"currency":"USD"},"status":{"time":"2025-06-02T15:32:53.690Z","success":true,"code":200,"message":"OK","responseTime":21,"creditsCost":1}}
    """
  end

  defp json_secondary_coin_history do
    """
    {"data":{"dates":["2025-05-28T00:00:00.000Z","2025-05-29T00:00:00.000Z","2025-05-30T00:00:00.000Z","2025-05-31T00:00:00.000Z","2025-06-01T00:00:00.000Z"],"volumes":[16697342.091162598,15904676.379819755,18808755.81579478,31779868.78666319,21254600.77892847],"prices":[6.669271727877,6.558096674134,6.443746862121,5.80657534093,5.903371964672],"currency":"USD"},"status":{"time":"2025-06-02T15:34:36.792Z","success":true,"code":200,"message":"OK","responseTime":49,"creditsCost":1}}
    """
  end
end
