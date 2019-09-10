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
end
