defmodule Explorer.Market.Source.DefiLlamaTest do
  use ExUnit.Case

  alias Explorer.Market.Source.DefiLlama
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    defillama_configuration = Application.get_env(:explorer, DefiLlama)
    source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

    Application.put_env(
      :explorer,
      Explorer.Market.Source,
      Keyword.merge(source_configuration || [],
        native_coin_source: DefiLlama,
        secondary_coin_source: DefiLlama,
        tokens_source: DefiLlama,
        native_coin_history_source: DefiLlama,
        secondary_coin_history_source: DefiLlama,
        market_cap_history_source: DefiLlama,
        tvl_history_source: DefiLlama
      )
    )

    Application.put_env(
      :explorer,
      DefiLlama,
      Keyword.merge(defillama_configuration || [],
        base_url: "http://localhost:#{bypass.port}",
        coin_id: "Ethereum"
      )
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
      Application.put_env(:explorer, DefiLlama, defillama_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "native_coin_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.native_coin_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_native_coin/0" do
    test "ignored" do
      assert DefiLlama.fetch_native_coin() == :ignore
    end
  end

  describe "secondary_coin_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.secondary_coin_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_secondary_coin/0" do
    test "ignored" do
      assert DefiLlama.fetch_secondary_coin() == :ignore
    end
  end

  describe "tokens_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.tokens_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_tokens/2" do
    test "ignored" do
      assert DefiLlama.fetch_tokens(nil, 10) == :ignore
    end
  end

  describe "native_coin_price_history_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.native_coin_price_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_native_coin_price_history/1" do
    test "ignored" do
      assert DefiLlama.fetch_native_coin_price_history(3) == :ignore
    end
  end

  describe "secondary_coin_price_history_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.secondary_coin_price_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_secondary_coin_price_history/1" do
    test "ignored" do
      assert DefiLlama.fetch_secondary_coin_price_history(3) == :ignore
    end
  end

  describe "market_cap_history_fetching_enabled?" do
    test "ignored" do
      assert DefiLlama.market_cap_history_fetching_enabled?() == :ignore
    end
  end

  describe "fetch_market_cap_history/1" do
    test "ignored" do
      assert DefiLlama.fetch_market_cap_history(3) == :ignore
    end
  end

  describe "tvl_history_fetching_enabled?" do
    test "returns true if coin_id is configured" do
      assert DefiLlama.tvl_history_fetching_enabled?()
    end

    test "returns false if coin_id is not configured" do
      config = Application.get_env(:explorer, DefiLlama)
      Application.put_env(:explorer, DefiLlama, Keyword.merge(config, coin_id: nil))

      refute DefiLlama.tvl_history_fetching_enabled?()
    end
  end

  describe "fetch_tvl_history/1" do
    test "fetches TVL history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/historicalChainTvl/Ethereum", fn conn ->
        Conn.resp(conn, 200, json_historical_chain_tvl())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  tvl: Decimal.new("50000000000")
                },
                %{
                  date: ~D[2025-02-13],
                  tvl: Decimal.new("51000000000")
                },
                %{
                  date: ~D[2025-02-14],
                  tvl: Decimal.new("52000000000")
                }
              ]} == DefiLlama.fetch_tvl_history(3)
    end

    test "returns error when coin_id not configured" do
      config = Application.get_env(:explorer, DefiLlama)
      Application.put_env(:explorer, DefiLlama, Keyword.merge(config, coin_id: nil))

      assert {:error, "Coin ID not specified"} == DefiLlama.fetch_tvl_history(3)
    end
  end

  defp json_historical_chain_tvl do
    """
    [
      {"date": 1739318400, "tvl": 50000000000},
      {"date": 1739404800, "tvl": 51000000000},
      {"date": 1739491200, "tvl": 52000000000}
    ]
    """
  end
end
