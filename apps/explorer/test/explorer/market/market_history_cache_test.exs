defmodule Explorer.Market.MarketHistoryCacheTest do
  use Explorer.DataCase

  alias Explorer.Market.MarketHistoryCache

  test "fetch/1" do
    test "caches data on the first call" do
      today = Date.utc_today()

      records =
        for i <- 0..30 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1),
            opening_price: Decimal.new(1)
          }
        end

      Market.bulk_insert_history(records)

      refute fetch_data()

      assert records == MarketHistoryCache.fetch()

      assert fetch_data == records
    end
  end

  def fetch_data do
    ConnCache.get(MarketHistoryCache.cache_name(), MarketHistoryCache.data_key())
  end
end
