# SPDX-License-Identifier: LicenseRef-Blockscout
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
      image_url: nil,
      circulating_supply: nil
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
      restart_market_history_cache()

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
      restart_market_history_cache()

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
      restart_market_history_cache()

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

      # `Coin.handle_info/2` above broadcasts the `:exchange_rate` chain event, which the `Main`
      # realtime handler processes in its own process, caching the market history that is still
      # empty at that moment. Wait until the handler is done with the event and drop what it has
      # cached, so that the history is read from the DB again.
      wait_for_realtime_handler()
      ConCache.delete(MarketHistoryCache.cache_name(), MarketHistoryCache.updated_at_key())
      ConCache.delete(MarketHistoryCache.cache_name(), MarketHistoryCache.data_key())

      assert Enum.map(Market.fetch_recent_history(), &Map.take(&1, [:date, :closing_price])) == records

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

  # `Coin.handle_info/2` broadcasts the `:exchange_rate` chain event, which the `Main` realtime
  # handler processes in its own process, reading the market history cache. Restarting the cache
  # while the handler is in the middle of that read drops the ETS table from under it and crashes
  # the handler, so the handler's mailbox must be drained first.
  defp restart_market_history_cache do
    wait_for_realtime_handler()
    Supervisor.terminate_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})
    Supervisor.restart_child(Explorer.Supervisor, {ConCache, MarketHistoryCache.cache_name()})
  end

  # Returns once the `Main` realtime handler has processed everything sent to it so far.
  defp wait_for_realtime_handler do
    if pid = Process.whereis(BlockScoutWeb.RealtimeEventHandlers.Main), do: :sys.get_state(pid)
  end
end
