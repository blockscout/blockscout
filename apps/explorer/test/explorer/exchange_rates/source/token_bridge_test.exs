defmodule Explorer.ExchangeRates.Source.TokenBridgeTest do
  use Explorer.DataCase

  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Source.CoinGecko
  alias Explorer.ExchangeRates.Source.TokenBridge
  alias Explorer.ExchangeRates.Token
  alias Plug.Conn

  @json "#{File.cwd!()}/test/support/fixture/exchange_rates/coin_gecko.json"
        |> File.read!()
        |> Jason.decode!()

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
      envs = Application.get_env(:explorer, ExchangeRates)
      Application.put_env(:explorer, ExchangeRates, Keyword.put(envs, :source, "coin_gecko"))
      Application.put_env(:explorer, CoinGecko, base_url: "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "bring a list with one %Token{}", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/exchange_rates", fn conn ->
        Conn.resp(conn, 200, @json_btc_price)
      end)

      assert [%Token{}] = TokenBridge.format_data(@json)
    end
  end
end
