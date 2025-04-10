defmodule BlockScoutWeb.V2.ExchangeRateChannelTest do
  use BlockScoutWeb.ChannelCase

  import Mox

  alias BlockScoutWeb.Notifier
  alias Explorer.Market.Fetcher.{Coin, History}
  alias Explorer.Market.{MarketHistory, Token}
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
      Coin.handle_info({nil, {{:ok, token}, false}}, %{})
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
        :timer.seconds(5) ->
          assert false, "Expected message received nothing."
      end
    end
  end
end
