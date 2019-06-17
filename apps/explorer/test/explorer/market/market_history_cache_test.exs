defmodule Explorer.Market.MarketHistoryCacheTest do
  use Explorer.DataCase

  alias Explorer.Market
  alias Explorer.Market.MarketHistoryCache

  describe "fetch/1" do
    test "caches data on the first call" do
      today = Date.utc_today()

      records =
        for i <- 0..29 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1),
            opening_price: Decimal.new(1)
          }
        end

      Market.bulk_insert_history(records)

      refute fetch_data()

      assert Enum.count(MarketHistoryCache.fetch()) == 30

      assert fetch_data() == records
    end
  end

  defp fetch_data do
    MarketHistoryCache.cache_name()
    |> ConCache.get(MarketHistoryCache.data_key())
    |> case do
      nil ->
        nil

      records ->
        Enum.map(records, fn record ->
          %{
            date: record.date,
            closing_price: record.closing_price,
            opening_price: record.opening_price
          }
        end)
    end
  end
end
