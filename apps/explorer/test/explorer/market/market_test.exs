defmodule Explorer.MarketTest do
  use Explorer.DataCase, async: false

  alias Explorer.Market
  alias Explorer.Market.MarketHistory

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())

    on_exit(fn ->
      Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
      Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    end)

    :ok
  end

  describe "fetch_recent_history/1" do
    test "with enabled history fetcher" do
      ConCache.delete(:market_history, :last_update)

      start_supervised!(Explorer.Market.Fetcher.History)
      start_supervised!(Explorer.Market)

      today = Date.utc_today()

      records =
        for i <- 0..29 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1),
            opening_price: Decimal.new(1)
          }
        end

      MarketHistory.bulk_insert(records)

      history = Market.fetch_recent_history()
      assert length(history) == 30
      assert Enum.at(history, 0).date == Enum.at(records, 0).date
    end

    test "with disabled history fetcher" do
      ConCache.delete(:market_history, :last_update)
      start_supervised!(Explorer.Market)

      old_env = Application.get_env(:explorer, Explorer.Market.Fetcher.History)
      Application.put_env(:explorer, Explorer.Market.Fetcher.History, Keyword.merge(old_env, enabled: false))

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Fetcher.History, old_env)
      end)

      today = Date.utc_today()

      records =
        for i <- 0..29 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1),
            opening_price: Decimal.new(1)
          }
        end

      MarketHistory.bulk_insert(records)

      history = Market.fetch_recent_history()
      assert length(history) == 0
    end
  end

  describe "get_coin_exchange_rate/0" do
    test "with enabled coin fetcher" do
      old_source_env = Application.get_env(:explorer, Explorer.Market.Source)
      old_fetcher_env = Application.get_env(:explorer, Explorer.Market.Fetcher.Coin)

      Application.put_env(
        :explorer,
        Explorer.Market.Source,
        Keyword.merge(old_source_env, native_coin_source: Explorer.Market.Source.OneCoinSource)
      )

      Application.put_env(:explorer, Explorer.Market.Fetcher.Coin, Keyword.merge(old_fetcher_env, enabled: true))

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Source, old_source_env)
        Application.put_env(:explorer, Explorer.Market.Fetcher.Coin, old_fetcher_env)
      end)

      start_supervised!(Explorer.Market.Fetcher.Coin)

      :timer.sleep(100)

      exchange_rate = Market.get_coin_exchange_rate()

      assert exchange_rate.fiat_value == Decimal.new(1)
    end

    test "with disabled coin fetcher" do
      exchange_rate = Market.get_coin_exchange_rate()
      assert exchange_rate.fiat_value == nil
    end
  end

  describe "get_secondary_coin_exchange_rate/0" do
    test "with enabled coin fetcher" do
      old_source_env = Application.get_env(:explorer, Explorer.Market.Source)
      old_fetcher_env = Application.get_env(:explorer, Explorer.Market.Fetcher.Coin)

      Application.put_env(
        :explorer,
        Explorer.Market.Source,
        Keyword.merge(old_source_env, secondary_coin_source: Explorer.Market.Source.OneCoinSource)
      )

      Application.put_env(:explorer, Explorer.Market.Fetcher.Coin, Keyword.merge(old_fetcher_env, enabled: true))

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Source, old_source_env)
        Application.put_env(:explorer, Explorer.Market.Fetcher.Coin, old_fetcher_env)
      end)

      start_supervised!(Explorer.Market.Fetcher.Coin)

      :timer.sleep(100)

      exchange_rate = Market.get_secondary_coin_exchange_rate()

      assert exchange_rate.fiat_value == Decimal.new(1)
    end

    test "with disabled coin fetcher" do
      exchange_rate = Market.get_secondary_coin_exchange_rate()
      assert exchange_rate.fiat_value == nil
    end
  end
end
