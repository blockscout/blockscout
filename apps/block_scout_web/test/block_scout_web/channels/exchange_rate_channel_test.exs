defmodule BlockScoutWeb.ExchangeRateChannelTest do
  use BlockScoutWeb.ChannelCase

  import Mox

  alias BlockScoutWeb.Notifier
  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.TestSource

  setup :verify_on_exit!

  setup do
    # Use TestSource mock and ets table for this test set
    configuration = Application.get_env(:explorer, Explorer.ExchangeRates)
    Application.put_env(:explorer, Explorer.ExchangeRates, source: TestSource)

    ExchangeRates.init([])

    token = %Token{
      available_supply: Decimal.new("1000000.0"),
      btc_value: Decimal.new("1.000"),
      id: "test",
      last_updated: DateTime.utc_now(),
      market_cap_usd: Decimal.new("1000000.0"),
      name: "test",
      symbol: Explorer.coin(),
      usd_value: Decimal.new("1.0"),
      volume_24h_usd: Decimal.new("1000.0")
    }

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ExchangeRates, configuration)
    end)

    {:ok, %{token: token}}
  end

  test "subscribed user is notified of new_rate event", %{token: token} do
    ExchangeRates.handle_info({nil, {:ok, [token]}}, %{})

    topic = "exchange_rate:new_rate"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :exchange_rate})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_rate", payload: payload} ->
        assert payload.exchange_rate == token
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end
end
