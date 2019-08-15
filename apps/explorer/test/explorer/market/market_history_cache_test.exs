defmodule Explorer.Market.MarketHistoryCacheTest do
  use Explorer.DataCase

  alias Explorer.Market
  alias Explorer.Market.MarketHistoryCache

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})
    Supervisor.restart_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})

    on_exit(fn ->
      Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
      Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    end)

    :ok
  end

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

    test "updates cache if cache is stale" do
      today = Date.utc_today()

      stale_records =
        for i <- 0..29 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1),
            opening_price: Decimal.new(1)
          }
        end

      Market.bulk_insert_history(stale_records)

      MarketHistoryCache.fetch()

      stale_updated_at = fetch_updated_at()

      assert fetch_data() == stale_records

      ConCache.put(MarketHistoryCache.cache_name(), MarketHistoryCache.updated_at_key(), 1)

      fetch_data()

      assert stale_updated_at != fetch_updated_at()
    end
  end

  defp fetch_updated_at do
    ConCache.get(MarketHistoryCache.cache_name(), MarketHistoryCache.updated_at_key())
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
