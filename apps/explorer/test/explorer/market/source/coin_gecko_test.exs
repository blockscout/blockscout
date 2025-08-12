# cspell:disable
defmodule Explorer.Market.Source.CoinGeckoTest do
  use ExUnit.Case

  alias Explorer.Market.Token
  alias Explorer.Market.Source.CoinGecko
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    coin_gecko_configuration = Application.get_env(:explorer, CoinGecko)
    source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

    Application.put_env(:explorer, Explorer.Market.Source,
      native_coin_source: CoinGecko,
      secondary_coin_source: CoinGecko,
      tokens_source: CoinGecko,
      native_coin_history_source: CoinGecko,
      secondary_coin_history_source: CoinGecko,
      market_cap_history_source: CoinGecko,
      tvl_history_source: CoinGecko
    )

    Application.put_env(:explorer, CoinGecko,
      base_url: "http://localhost:#{bypass.port}",
      coin_id: "native_coin_id",
      secondary_coin_id: "secondary_coin_id",
      currency: "aed",
      platform: "test"
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
      Application.put_env(:explorer, CoinGecko, coin_gecko_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "fetch_native_coin/0" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/native_coin_id", fn conn ->
        assert conn.query_string ==
                 "localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"

        Conn.resp(conn, 200, json_coin("native_coin_id", "123"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120547760.0137619"),
                total_supply: Decimal.new("120547760.0137619"),
                btc_value: Decimal.new("0.02785102"),
                last_updated: ~U[2025-02-14 05:40:07.774Z],
                market_cap: Decimal.new("1193060259516"),
                tvl: nil,
                name: "Ethereum",
                symbol: "ETH",
                fiat_value: Decimal.new("123"),
                volume_24h: Decimal.new("66154765984"),
                image_url: "https://coin-images.coingecko.com/coins/images/279/small/ethereum.png?1696501628"
              }} == CoinGecko.fetch_native_coin()
    end
  end

  describe "fetch_secondary_coin/0" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/secondary_coin_id", fn conn ->
        assert conn.query_string ==
                 "localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"

        Conn.resp(conn, 200, json_coin("secondary_coin_id", "324"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120547760.0137619"),
                total_supply: Decimal.new("120547760.0137619"),
                btc_value: Decimal.new("0.02785102"),
                last_updated: ~U[2025-02-14 05:40:07.774Z],
                market_cap: Decimal.new("1193060259516"),
                tvl: nil,
                name: "Ethereum",
                symbol: "ETH",
                fiat_value: Decimal.new("324"),
                volume_24h: Decimal.new("66154765984"),
                image_url: "https://coin-images.coingecko.com/coins/images/279/small/ethereum.png?1696501628"
              }} == CoinGecko.fetch_secondary_coin()
    end
  end

  describe "fetch_tokens/2" do
    test "fetches list of tokens", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, json_coins_list())
      end)

      Bypass.expect_once(bypass, "GET", "/simple/price", fn conn ->
        assert conn.query_string == "vs_currencies=aed&include_market_cap=true&include_24hr_vol=true&ids=4,3,1"
        Conn.resp(conn, 200, json_simple_price())
      end)

      assert {:ok, [], true,
              [
                %{
                  id: "1",
                  name: "1",
                  type: "ERC-20",
                  symbol: "1",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
                  },
                  circulating_market_cap: Decimal.new("100"),
                  fiat_value: Decimal.new("1"),
                  volume_24h: Decimal.new("10")
                },
                %{
                  id: "3",
                  name: "3",
                  type: "ERC-20",
                  symbol: "3",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
                  },
                  circulating_market_cap: Decimal.new("300.03"),
                  fiat_value: Decimal.new("3.3"),
                  volume_24h: Decimal.new("33.333")
                },
                %{
                  id: "4",
                  name: "4",
                  type: "ERC-20",
                  symbol: "4",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4>>
                  },
                  circulating_market_cap: Decimal.new("4"),
                  fiat_value: Decimal.new("4"),
                  volume_24h: Decimal.new("4")
                }
              ]} == CoinGecko.fetch_tokens(nil, 5)
    end

    test "takes into account batch size", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, json_coins_list())
      end)

      Bypass.expect_once(bypass, "GET", "/simple/price", fn conn ->
        assert conn.query_string == "vs_currencies=aed&include_market_cap=true&include_24hr_vol=true&ids=4,3"
        Conn.resp(conn, 200, json_simple_price())
      end)

      assert {:ok,
              [
                %{
                  id: "1",
                  name: "1",
                  type: "ERC-20",
                  symbol: "1",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
                  }
                }
              ], false,
              [
                %{
                  id: "3",
                  name: "3",
                  type: "ERC-20",
                  symbol: "3",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
                  },
                  circulating_market_cap: Decimal.new("300.03"),
                  fiat_value: Decimal.new("3.3"),
                  volume_24h: Decimal.new("33.333")
                },
                %{
                  id: "4",
                  name: "4",
                  type: "ERC-20",
                  symbol: "4",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4>>
                  },
                  circulating_market_cap: Decimal.new("4"),
                  fiat_value: Decimal.new("4"),
                  volume_24h: Decimal.new("4")
                }
              ]} == CoinGecko.fetch_tokens(nil, 2)
    end
  end

  describe "fetch_native_coin_price_history/1" do
    test "fetches native coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/native_coin_id/market_chart", fn conn ->
        assert conn.query_string == "vs_currency=aed&days=3"

        Conn.resp(conn, 200, json_coin_market_chart())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("4.4"),
                  secondary_coin: false
                }
              ]} == CoinGecko.fetch_native_coin_price_history(3)
    end
  end

  describe "fetch_secondary_coin_price_history/1" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/secondary_coin_id/market_chart", fn conn ->
        assert conn.query_string == "vs_currency=aed&days=3"

        Conn.resp(conn, 200, json_coin_market_chart())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("4.4"),
                  secondary_coin: true
                }
              ]} == CoinGecko.fetch_secondary_coin_price_history(3)
    end
  end

  describe "fetch_market_cap_history/1" do
    test "fetches market cap history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/coins/native_coin_id/market_chart", fn conn ->
        assert conn.query_string == "vs_currency=aed&days=3"

        Conn.resp(conn, 200, json_coin_market_chart())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  market_cap: Decimal.new("2.2")
                },
                %{
                  date: ~D[2025-02-13],
                  market_cap: Decimal.new("3.3")
                },
                %{
                  date: ~D[2025-02-14],
                  market_cap: Decimal.new("4.4")
                }
              ]} == CoinGecko.fetch_market_cap_history(3)
    end
  end

  defp json_coin(coin_id, fiat_value) do
    """
    {
      "id": "#{coin_id}",
      "symbol": "eth",
      "name": "Ethereum",
      "web_slug": "ethereum",
      "asset_platform_id": null,
      "platforms": {
        "": ""
      },
      "detail_platforms": {
        "": {
          "decimal_place": null,
          "contract_address": ""
        }
      },
      "block_time_in_minutes": 0,
      "hashing_algorithm": "Ethash",
      "categories": [
        "Smart Contract Platform",
        "Layer 1 (L1)",
        "Ethereum Ecosystem",
        "FTX Holdings",
        "Multicoin Capital Portfolio",
        "Proof of Stake (PoS)",
        "Alameda Research Portfolio",
        "Andreessen Horowitz (a16z) Portfolio",
        "GMCI Layer 1 Index",
        "GMCI 30 Index",
        "Delphi Ventures Portfolio",
        "Galaxy Digital Portfolio",
        "GMCI Index",
        "World Liberty Financial Portfolio"
      ],
      "preview_listing": false,
      "public_notice": null,
      "additional_notices": [],
      "description": {
        "en": "Ethereum is a global, open-source platform for decentralized applications. In other words, the vision is to create a world computer that anyone can build applications in a decentralized manner; while all states and data are distributed and publicly accessible. Ethereum supports smart contracts in which developers can write code in order to program digital value. Examples of decentralized apps (dapps) that are built on Ethereum includes tokens, non-fungible tokens, decentralized finance apps, lending protocol, decentralized exchanges, and much more. On Ethereum, all transactions and smart contract executions require a small fee to be paid. This fee is called Gas. In technical terms, Gas refers to the unit of measure on the amount of computational effort required to execute an operation or a smart contract. The more complex the execution operation is, the more gas is required to fulfill that operation. Gas fees are paid entirely in Ether (ETH), which is the native coin of the blockchain. The price of gas can fluctuate from time to time depending on the network demand."
      },
      "links": {
        "homepage": [
          "https://www.ethereum.org/"
        ],
        "whitepaper": "",
        "blockchain_site": [
          "https://etherscan.io/",
          "https://platform.arkhamintelligence.com/explorer/token/ethereum",
          "https://ethplorer.io/",
          "https://blockchair.com/ethereum",
          "https://eth.tokenview.io/",
          "https://www.oklink.com/eth",
          "https://3xpl.com/ethereum"
        ],
        "official_forum_url": [],
        "chat_url": [],
        "announcement_url": [],
        "snapshot_url": null,
        "twitter_screen_name": "ethereum",
        "facebook_username": "",
        "bitcointalk_thread_identifier": null,
        "telegram_channel_identifier": "",
        "subreddit_url": "https://www.reddit.com/r/ethereum",
        "repos_url": {
          "github": [
            "https://github.com/ethereum/go-ethereum",
            "https://github.com/ethereum/py-evm",
            "https://github.com/ethereum/aleth",
            "https://github.com/ethereum/web3.py",
            "https://github.com/ethereum/solidity",
            "https://github.com/ethereum/sharding",
            "https://github.com/ethereum/casper",
            "https://github.com/paritytech/parity"
          ],
          "bitbucket": []
        }
      },
      "image": {
        "thumb": "https://coin-images.coingecko.com/coins/images/279/thumb/ethereum.png?1696501628",
        "small": "https://coin-images.coingecko.com/coins/images/279/small/ethereum.png?1696501628",
        "large": "https://coin-images.coingecko.com/coins/images/279/large/ethereum.png?1696501628"
      },
      "country_origin": "",
      "genesis_date": "2015-07-30",
      "sentiment_votes_up_percentage": 80,
      "sentiment_votes_down_percentage": 20,
      "ico_data": {
        "ico_start_date": "2014-07-20T00:00:00.000Z",
        "ico_end_date": "2014-09-01T00:00:00.000Z",
        "short_desc": "A decentralized platform for applications",
        "description": null,
        "links": {},
        "softcap_currency": "",
        "hardcap_currency": "",
        "total_raised_currency": "",
        "softcap_amount": null,
        "hardcap_amount": null,
        "total_raised": null,
        "quote_pre_sale_currency": "",
        "base_pre_sale_amount": null,
        "quote_pre_sale_amount": null,
        "quote_public_sale_currency": "BTC",
        "base_public_sale_amount": 1,
        "quote_public_sale_amount": 0.00074794,
        "accepting_currencies": "",
        "country_origin": "",
        "pre_sale_start_date": null,
        "pre_sale_end_date": null,
        "whitelist_url": "",
        "whitelist_start_date": null,
        "whitelist_end_date": null,
        "bounty_detail_url": "",
        "amount_for_sale": null,
        "kyc_required": true,
        "whitelist_available": null,
        "pre_sale_available": null,
        "pre_sale_ended": false
      },
      "watchlist_portfolio_users": 1632634,
      "market_cap_rank": 2,
      "market_data": {
        "current_price": {
          "aed": #{fiat_value},
          "btc": 0.02785102,
          "usd": 2694.15
        },
        "total_value_locked": null,
        "mcap_to_tvl_ratio": null,
        "fdv_to_tvl_ratio": null,
        "roi": {
          "times": 36.23697002905095,
          "currency": "btc",
          "percentage": 3623.6970029050954
        },
        "ath": {
          "aed": 17918.33,
          "btc": 0.1474984,
          "usd": 4878.26
        },
        "ath_change_percentage": {
          "aed": -44.65876,
          "btc": -81.09997,
          "usd": -44.65725
        },
        "ath_date": {
          "aed": "2021-11-10T14:24:19.604Z",
          "btc": "2017-06-12T00:00:00.000Z",
          "usd": "2021-11-10T14:24:19.604Z"
        },
        "atl": {
          "aed": 1.59,
          "btc": 0.00160204,
          "usd": 0.432979
        },
        "atl_change_percentage": {
          "aed": 623423.92957,
          "btc": 1640.10518,
          "usd": 623432.41751
        },
        "atl_date": {
          "aed": "2015-10-20T00:00:00.000Z",
          "btc": "2015-10-20T00:00:00.000Z",
          "usd": "2015-10-20T00:00:00.000Z"
        },
        "market_cap": {
          "aed": 1193060259516,
          "btc": 3357706,
          "usd": 324819019743
        },
        "market_cap_rank": 2,
        "fully_diluted_valuation": {
          "aed": 1193060259516,
          "btc": 3357706,
          "usd": 324819019743
        },
        "market_cap_fdv_ratio": 1,
        "total_volume": {
          "aed": 66154765984,
          "btc": 186192,
          "usd": 18011098825
        },
        "high_24h": {
          "aed": 10006.09,
          "btc": 0.02815607,
          "usd": 2724.21
        },
        "low_24h": {
          "aed": 9622.03,
          "btc": 0.02742768,
          "usd": 2619.67
        },
        "price_change_24h": -28.468197850417,
        "price_change_percentage_24h": -1.04562,
        "price_change_percentage_7d": -0.954,
        "price_change_percentage_14d": -16.22216,
        "price_change_percentage_30d": -16.47229,
        "price_change_percentage_60d": -31.86721,
        "price_change_percentage_200d": -19.51862,
        "price_change_percentage_1y": 2.50225,
        "market_cap_change_24h": -3492411535.1411,
        "market_cap_change_percentage_24h": -1.06375,
        "price_change_24h_in_currency": {
          "aed": -104.6181430229608,
          "btc": -0.000290739745482781,
          "usd": -28.468197850417255
        },
        "price_change_percentage_1h_in_currency": {
          "btc": -0.25626,
          "usd": -0.38994
        },
        "price_change_percentage_24h_in_currency": {
          "aed": -1.04616,
          "btc": -1.03313,
          "usd": -1.04562
        },
        "price_change_percentage_7d_in_currency": {
          "aed": -0.95357,
          "btc": -0.18775,
          "usd": -0.954
        },
        "price_change_percentage_14d_in_currency": {
          "aed": -16.222,
          "btc": -9.93596,
          "usd": -16.22216
        },
        "price_change_percentage_30d_in_currency": {
          "aed": -16.47229,
          "btc": -16.10832,
          "usd": -16.47229
        },
        "price_change_percentage_60d_in_currency": {
          "aed": -31.86721,
          "btc": -26.31145,
          "usd": -31.86721
        },
        "price_change_percentage_200d_in_currency": {
          "aed": -19.51741,
          "btc": -42.1504,
          "usd": -19.51862
        },
        "price_change_percentage_1y_in_currency": {
          "aed": 2.50504,
          "btc": -47.62855,
          "usd": 2.50225
        },
        "market_cap_change_24h_in_currency": {
          "aed": -12834193797.197998,
          "btc": -33744.64172904473,
          "usd": -3492411535.1411133
        },
        "market_cap_change_percentage_24h_in_currency": {
          "aed": -1.06429,
          "btc": -0.99499,
          "usd": -1.06375
        },
        "total_supply": 120547760.0137619,
        "max_supply": null,
        "max_supply_infinite": true,
        "circulating_supply": 120547760.0137619,
        "last_updated": "2025-02-14T05:40:07.774Z"
      },
      "status_updates": [],
      "last_updated": "2025-02-14T05:40:07.774Z"
    }
    """
  end

  defp json_coins_list do
    """
    [{
      "id": "1",
      "symbol": "1",
      "name": "1",
      "platforms": {
        "test": "0x0000000000000000000000000000000000000001"
      }
    },
    {
      "id": "2",
      "symbol": "2",
      "name": "2",
      "platforms": {
        "binance-smart-chain": "0x012a6a39eec345a0ea2b994b17875e721d17ee45"
      }
    },
    {
      "id": "3",
      "symbol": "3",
      "name": "3",
      "platforms": {
        "test": "0x0000000000000000000000000000000000000003"
      }
    },
    {
      "id": "4",
      "symbol": "4",
      "name": "4",
      "platforms": {
        "test": "0x0000000000000000000000000000000000000004",
        "binance-smart-chain": "0x012a6a39eec345a0ea2b994b17875e721d17ee45"
      }
    }]
    """
  end

  defp json_simple_price do
    """
    {
      "1": {
        "aed": 1,
        "aed_market_cap": 100,
        "aed_24h_vol": 10
      },
      "3": {
        "aed": 3.3,
        "aed_market_cap": 300.03,
        "aed_24h_vol": 33.333
      },
      "4": {
        "aed": 4,
        "aed_market_cap": 4,
        "aed_24h_vol": 4
      }
    }
    """
  end

  defp json_coin_market_chart do
    """
    {
      "prices": [
        [
          1739318400000,
          1.1
        ],
        [
          1739404800000,
          2.2
        ],
        [
          1739491200000,
          3.3
        ],
        [
          1739518106000,
          4.4
        ]
      ],
      "market_caps": [
        [
          1739318400000,
          1.1
        ],
        [
          1739404800000,
          2.2
        ],
        [
          1739491200000,
          3.3
        ],
        [
          1739518106000,
          4.4
        ]
      ],
      "total_volumes": [
        [
          1739318400000,
          77915018742.98099
        ],
        [
          1739404800000,
          97348474865.08902
        ],
        [
          1739491200000,
          69559976333.78288
        ],
        [
          1739518106000,
          64287364164.68306
        ]
      ]
    }
    """
  end
end
