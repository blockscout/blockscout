defmodule BlockScoutWeb.V2.ExchangeRateChannelTest do
  use BlockScoutWeb.ChannelCase

  import Mox

  alias BlockScoutWeb.Notifier
  alias Explorer.Market.Fetcher.Coin
  alias Explorer.Market.{MarketHistory, MarketHistoryCache, Token}
  alias Explorer.Market.Source.OneCoinSource
  alias Explorer.Market

  setup :verify_on_exit!

  setup do
    # Use TestSource mock and ets table for this test set
    coin_fetcher_configuration = Application.get_env(:explorer, Coin)
    market_configuration = Application.get_env(:explorer, Market)
    Application.put_env(:explorer, Market, native_coin_source: OneCoinSource)
    Application.put_env(:explorer, Coin, enabled: true, store: :ets)

    Coin.init([])

    token = %Token{
      available_supply: Decimal.new(10_000_000),
      total_supply: Decimal.new(10_000_000_000),
      btc_value: Decimal.new(1),
      last_updated: Timex.now(),
      market_cap: Decimal.new(10_000_000),
      tvl: Decimal.new(100_500_000),
      name: "",
      symbol: Explorer.coin(),
      fiat_value: Decimal.new(1),
      volume_24h: Decimal.new(1),
      image_url: nil
    }

    on_exit(fn ->
      Application.put_env(:explorer, Coin, coin_fetcher_configuration)
      Application.put_env(:explorer, Market, market_configuration)
    end)

    {:ok, %{token: token}}
  end

  describe "new_rate" do
    test "subscribed user is notified", %{token: token} do
      Coin.handle_info({nil, {{:ok, token}, false}}, %{})
      Supervisor.terminate_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})
      Supervisor.restart_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})

      topic = "exchange_rate:new_rate"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :exchange_rate})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_rate", payload: payload} ->
          assert payload.exchange_rate == token.fiat_value
          assert payload.chart_data == []
      after
        :timer.seconds(5) ->
          assert false, "Expected message received nothing."
      end
    end

    test "subscribed user is notified with market history", %{token: token} do
      initial_market_history_fetcher_enabled_value = :persistent_term.get(:market_history_fetcher_enabled, false)
      :persistent_term.put(:market_history_fetcher_enabled, true)
      Supervisor.terminate_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})
      Supervisor.restart_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})

      source_configuration = Application.get_env(:explorer, Explorer.Market.Source)
      fetcher_configuration = Application.get_env(:explorer, Coin)

      Application.put_env(:explorer, Explorer.Market.Source,
        native_coin_source: OneCoinSource,
        secondary_coin_source: OneCoinSource
      )

      Application.put_env(:explorer, Coin, Keyword.merge(fetcher_configuration, table_name: :rates, enabled: true))

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
        Application.put_env(:explorer, Coin, fetcher_configuration)
        Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
        Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
        :persistent_term.put(:market_history_fetcher_enabled, initial_market_history_fetcher_enabled_value)
      end)

      {:ok, state} = Coin.init([])
      Coin.handle_info({nil, {{:ok, token}, false}}, state)
      Supervisor.terminate_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})
      Supervisor.restart_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})

      today = Date.utc_today()

      old_records =
        for i <- 1..29 do
          %{
            date: Timex.shift(today, days: i * -1),
            closing_price: Decimal.new(1)
          }
        end

      records = [%{date: today, closing_price: token.fiat_value} | old_records]

      MarketHistory.bulk_insert(records)

      Market.fetch_recent_history()

      topic = "exchange_rate:new_rate"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :exchange_rate})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_rate", payload: payload} ->
          assert payload.exchange_rate == token.fiat_value
          assert payload.chart_data == records
      after
        :timer.seconds(10) ->
          assert false, "Expected message received nothing."
      end
    end
  end
end
