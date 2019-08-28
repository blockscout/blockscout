defmodule Explorer.ExchangeRates.Source.TokenBridgeTest do
  use Explorer.DataCase
  alias Explorer.ExchangeRates.Source.TokenBridge
  alias Explorer.ExchangeRates.Token

  @json "#{File.cwd!()}/test/support/fixture/exchange_rates/coin_gecko.json"
        |> File.read!()
        |> Jason.decode!()

  describe "format_data/1" do
    test "bring a list with one %Token{}" do
      assert [%Token{}] = TokenBridge.format_data(@json)
    end
  end
end
