# cspell:disable
defmodule Explorer.Market.Source.MobulaTest do
  use ExUnit.Case

  alias Explorer.Market.Source.Mobula
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    mobula_configuration = Application.get_env(:explorer, Mobula)
    source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

    Application.put_env(
      :explorer,
      Explorer.Market.Source,
      Keyword.merge(source_configuration || [],
        native_coin_source: Mobula,
        secondary_coin_source: Mobula,
        tokens_source: Mobula,
        native_coin_history_source: Mobula,
        secondary_coin_history_source: Mobula,
        market_cap_history_source: Mobula,
        tvl_history_source: Mobula
      )
    )

    Application.put_env(
      :explorer,
      Mobula,
      Keyword.merge(mobula_configuration || [],
        base_url: "http://localhost:#{bypass.port}",
        coin_id: "native_coin",
        secondary_coin_id: "secondary_coin",
        platform: "test_platform"
      )
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
      Application.put_env(:explorer, Mobula, mobula_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "native_coin_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert Mobula.native_coin_fetching_enabled?()
    end

    test "returns false if coin_id is not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, coin_id: nil))

      refute Mobula.native_coin_fetching_enabled?()
    end
  end

  describe "fetch_native_coin/0" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/data", fn conn ->
        assert conn.query_string == "asset=native_coin"
        Conn.resp(conn, 200, json_market_data("native_coin", "2500.5"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120000000"),
                total_supply: Decimal.new("150000000"),
                btc_value: nil,
                last_updated: nil,
                market_cap: Decimal.new("300000000000"),
                tvl: nil,
                name: "Ethereum",
                symbol: "ETH",
                fiat_value: Decimal.new("2500.5"),
                volume_24h: Decimal.new("15000000000"),
                image_url: "https://example.com/eth.png"
              }} == Mobula.fetch_native_coin()
    end

    test "returns error when coin_id not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, coin_id: nil))

      assert {:error, "Coin ID not specified"} == Mobula.fetch_native_coin()
    end
  end

  describe "secondary_coin_fetching_enabled?" do
    test "returns true if secondary_coin_id is configured" do
      assert Mobula.secondary_coin_fetching_enabled?()
    end

    test "returns false if secondary_coin_id is not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, secondary_coin_id: nil))

      refute Mobula.secondary_coin_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin/0" do
    test "fetches secondary coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/data", fn conn ->
        assert conn.query_string == "asset=secondary_coin"
        Conn.resp(conn, 200, json_market_data("secondary_coin", "95000.0"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("120000000"),
                total_supply: Decimal.new("150000000"),
                btc_value: nil,
                last_updated: nil,
                market_cap: Decimal.new("300000000000"),
                tvl: nil,
                name: "Ethereum",
                symbol: "ETH",
                fiat_value: Decimal.new("9.5E+4"),
                volume_24h: Decimal.new("15000000000"),
                image_url: "https://example.com/eth.png"
              }} == Mobula.fetch_secondary_coin()
    end

    test "returns error when secondary_coin_id not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, secondary_coin_id: nil))

      assert {:error, "Secondary coin ID not specified"} == Mobula.fetch_secondary_coin()
    end
  end

  describe "tokens_fetching_enabled?" do
    test "returns true if platform is configured" do
      assert Mobula.tokens_fetching_enabled?()
    end

    test "returns false if platform is not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, platform: nil))

      refute Mobula.tokens_fetching_enabled?()
    end
  end

  describe "fetch_tokens/2" do
    test "fetches tokens with nil state", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/query", fn conn ->
        assert conn.query_string == "sortBy=market_cap&blockchain=test_platform&limit=5&offset=0"
        Conn.resp(conn, 200, json_market_query())
      end)

      assert {:ok, nil, true,
              [
                %{
                  name: "Token B",
                  symbol: "TKB",
                  type: "ERC-20",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
                  },
                  fiat_value: Decimal.new("2.0"),
                  volume_24h: Decimal.new("200000"),
                  circulating_market_cap: Decimal.new("2000000"),
                  circulating_supply: Decimal.new("1000000"),
                  icon_url: "https://example.com/tkb.png"
                },
                %{
                  name: "Token A",
                  symbol: "TKA",
                  type: "ERC-20",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
                  },
                  fiat_value: Decimal.new("1.5"),
                  volume_24h: Decimal.new("100000"),
                  circulating_market_cap: Decimal.new("1500000"),
                  circulating_supply: Decimal.new("1000000"),
                  icon_url: "https://example.com/tka.png"
                }
              ]} == Mobula.fetch_tokens(nil, 5)
    end

    test "paginates with batch size", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/query", fn conn ->
        assert conn.query_string == "sortBy=market_cap&blockchain=test_platform&limit=1&offset=0"
        Conn.resp(conn, 200, json_market_query_single())
      end)

      assert {:ok, 1, false,
              [
                %{
                  name: "Token A",
                  symbol: "TKA",
                  type: "ERC-20",
                  contract_address_hash: %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
                  },
                  fiat_value: Decimal.new("1.5"),
                  volume_24h: Decimal.new("100000"),
                  circulating_market_cap: Decimal.new("1500000"),
                  circulating_supply: Decimal.new("1000000"),
                  icon_url: "https://example.com/tka.png"
                }
              ]} == Mobula.fetch_tokens(nil, 1)
    end
  end

  describe "native_coin_price_history_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert Mobula.native_coin_price_history_fetching_enabled?()
    end

    test "returns false if coin_id is not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, coin_id: nil))

      refute Mobula.native_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_native_coin_price_history/1" do
    test "fetches native coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/history", fn conn ->
        assert conn.query_string =~ "asset=native_coin&from="
        Conn.resp(conn, 200, json_market_history())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("2.5E+3"),
                  closing_price: Decimal.new("2.5E+3"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.6E+3"),
                  closing_price: Decimal.new("2.6E+3"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("2.7E+3"),
                  closing_price: Decimal.new("2.7E+3"),
                  secondary_coin: false
                }
              ]} == Mobula.fetch_native_coin_price_history(3)
    end
  end

  describe "secondary_coin_price_history_fetching_enabled?" do
    test "returns true if secondary_coin_id is configured" do
      assert Mobula.secondary_coin_price_history_fetching_enabled?()
    end

    test "returns false if secondary_coin_id is not configured" do
      config = Application.get_env(:explorer, Mobula)
      Application.put_env(:explorer, Mobula, Keyword.merge(config, secondary_coin_id: nil))

      refute Mobula.secondary_coin_price_history_fetching_enabled?()
    end
  end

  describe "fetch_secondary_coin_price_history/1" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/market/history", fn conn ->
        assert conn.query_string =~ "asset=secondary_coin&from="
        Conn.resp(conn, 200, json_market_history())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("2.5E+3"),
                  closing_price: Decimal.new("2.5E+3"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.6E+3"),
                  closing_price: Decimal.new("2.6E+3"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("2.7E+3"),
                  closing_price: Decimal.new("2.7E+3"),
                  secondary_coin: true
                }
              ]} == Mobula.fetch_secondary_coin_price_history(3)
    end
  end

  describe "market_cap_history_fetching_enabled?" do
    test "ignored" do
      assert Mobula.market_cap_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_market_cap_history/1" do
    test "ignored" do
      assert Mobula.fetch_market_cap_history(3) == :ignore
    end
  end

  describe "tvl_history_fetching_enabled?" do
    test "ignored" do
      assert Mobula.tvl_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_tvl_history/1" do
    test "ignored" do
      assert Mobula.fetch_tvl_history(3) == :ignore
    end
  end

  defp json_market_data(_coin_id, price) do
    """
    {
      "data": {
        "name": "Ethereum",
        "symbol": "ETH",
        "price": #{price},
        "market_cap": 300000000000,
        "circulating_supply": 120000000,
        "total_supply": 150000000,
        "off_chain_volume": 15000000000,
        "logo": "https://example.com/eth.png"
      }
    }
    """
  end

  defp json_market_query do
    """
    [
      {
        "name": "Token A",
        "symbol": "TKA",
        "price": 1.5,
        "market_cap": 1500000,
        "circulating_supply": 1000000,
        "off_chain_volume": 100000,
        "logo": "https://example.com/tka.png",
        "contracts": [{"address": "0x0000000000000000000000000000000000000001"}]
      },
      {
        "name": "Token B",
        "symbol": "TKB",
        "price": 2.0,
        "market_cap": 2000000,
        "circulating_supply": 1000000,
        "off_chain_volume": 200000,
        "logo": "https://example.com/tkb.png",
        "contracts": [{"address": "0x0000000000000000000000000000000000000002"}]
      }
    ]
    """
  end

  defp json_market_query_single do
    """
    [
      {
        "name": "Token A",
        "symbol": "TKA",
        "price": 1.5,
        "market_cap": 1500000,
        "circulating_supply": 1000000,
        "off_chain_volume": 100000,
        "logo": "https://example.com/tka.png",
        "contracts": [{"address": "0x0000000000000000000000000000000000000001"}]
      }
    ]
    """
  end

  defp json_market_history do
    """
    {
      "data": {
        "price_history": [
          [1739318400000, 2500.0],
          [1739404800000, 2600.0],
          [1739491200000, 2700.0]
        ]
      }
    }
    """
  end
end
