defmodule Explorer.ExchangeRates.Source.TransactionAndLogTest do
  use Explorer.DataCase
  alias Explorer.ExchangeRates.Source.TransactionAndLog
  alias Explorer.ExchangeRates.Token

  describe "fetch_exchange_rates/1" do
    test "bring a list with one %Token{}" do
      assert {:ok, [%Token{}]} = TransactionAndLog.fetch_exchange_rates()
    end
  end
end
