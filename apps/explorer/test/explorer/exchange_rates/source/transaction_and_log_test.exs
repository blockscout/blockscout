defmodule Explorer.ExchangeRates.Source.TransactionAndLogTest do
  use Explorer.DataCase
  alias Explorer.ExchangeRates.Source.TransactionAndLog
  alias Explorer.ExchangeRates.Token

  @json """
  [
    {
      "id": "poa-network",
      "name": "POA Network",
      "symbol": "POA",
      "rank": "103",
      "price_usd": "0.485053",
      "price_btc": "0.00007032",
      "24h_volume_usd": "20185000.0",
      "market_cap_usd": "98941986.0",
      "available_supply": "203981804.0",
      "total_supply": "254473964.0",
      "max_supply": null,
      "percent_change_1h": "-0.66",
      "percent_change_24h": "12.34",
      "percent_change_7d": "49.15",
      "last_updated": "1523473200"
    }
  ]
  """

  describe "format_data/1" do
    test "bring a list with one %Token{}" do
      assert [%Token{}] = TransactionAndLog.format_data(@json)
    end
  end
end
