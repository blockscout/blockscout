defmodule BlockScoutWeb.ExchangeRateChannelTest do
  use BlockScoutWeb.ChannelCase

  import Mox

  alias BlockScoutWeb.Notifier
  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.TestSource
  alias Explorer.Market

  setup :verify_on_exit!

  setup do
    # Use TestSource mock and ets table for this test set
    configuration = Application.get_env(:explorer, Explorer.ExchangeRates)
    Application.put_env(:explorer, Explorer.ExchangeRates, source: TestSource)
    Application.put_env(:explorer, Explorer.ExchangeRates, table_name: :rates)
    Application.put_env(:explorer, Explorer.ExchangeRates, enabled: true)

    ExchangeRates.init([])

    token = %Token{
      available_supply: Decimal.new("1000000.0"),
      total_supply: Decimal.new("1000000.0"),
      btc_value: Decimal.new("1.000"),
      id: "test",
      last_updated: DateTime.utc_now(),
      market_cap_usd: Decimal.new("1000000.0"),
      name: "test",
      symbol: Explorer.coin(),
      usd_value: Decimal.new("2.5"),
      volume_24h_usd: Decimal.new("1000.0")
    }

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ExchangeRates, configuration)
    end)

    {:ok, %{token: token}}
  end

  describe "new_rate" do
    test "subscribed user is notified", %{token: token} do
      ExchangeRates.handle_info({nil, {:ok, [token]}}, %{})
      Supervisor.terminate_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})
      Supervisor.restart_child(Explorer.Supervisor, {ConCache, Explorer.Market.MarketHistoryCache.cache_name()})

      topic = "exchange_rate:new_rate"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :exchange_rate})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_rate", payload: payload} ->
          assert payload.exchange_rate == Map.from_struct(token)
          assert payload.market_history_data == []
      after
        :timer.seconds(5) ->
          assert false, "Expected message received nothing."
      end
    end

    test "subscribed user is notified with market history", %{token: token} do
      ExchangeRates.handle_info({nil, {:ok, [token]}}, %{})
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

      records = [%{date: today, closing_price: token.usd_value} | old_records]

      Market.bulk_insert_history(records)

      Market.fetch_recent_history()

      topic = "exchange_rate:new_rate"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :exchange_rate})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_rate", payload: payload} ->
          assert payload.exchange_rate == Map.from_struct(token)
          assert payload.market_history_data == records
      after
        :timer.seconds(5) ->
          assert false, "Expected message received nothing."
      end
    end
  end
end
