defmodule Explorer.ExchangeRatesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Rate
  alias Explorer.ExchangeRates.Source.TestSource

  @moduletag :capture_log

  setup :verify_on_exit!

  test "start_link" do
    stub(TestSource, :fetch_exchange_rate, fn _ -> {:ok, %Rate{}} end)
    set_mox_global()

    assert {:ok, _} = ExchangeRates.start_link([])
  end

  test "init" do
    assert :ets.info(ExchangeRates.table_name()) == :undefined

    assert {:ok, %{}} == ExchangeRates.init([])
    assert_received :update
    table = :ets.info(ExchangeRates.table_name())
    refute table == :undefined
    assert table[:name] == ExchangeRates.table_name()
    assert table[:named_table]
    assert table[:read_concurrency]
    assert table[:type] == :set
    assert table[:write_concurrency]
  end

  test "handle_info with :update" do
    ExchangeRates.init([])
    ticker = "poa-network"
    state = %{}

    expect(TestSource, :fetch_exchange_rate, fn ^ticker -> {:ok, %Rate{}} end)
    set_mox_global()

    assert {:noreply, ^state} = ExchangeRates.handle_info(:update, state)
    assert_receive {_, {^ticker, _}}
  end

  describe "ticker fetch task" do
    setup do
      ExchangeRates.init([])
      :ok
    end

    test "with successful fetch" do
      expected_rate = %Rate{
        id: "test",
        last_updated: DateTime.utc_now(),
        name: "test",
        symbol: "test",
        usd_value: "9000.000001"
      }

      id = expected_rate.id
      state = %{}

      assert {:noreply, ^state} =
               ExchangeRates.handle_info({nil, {id, {:ok, expected_rate}}}, state)

      assert [{^id, ^expected_rate}] = :ets.lookup(ExchangeRates.table_name(), id)
    end

    test "with failed fetch" do
      ticker = "failed-ticker"
      state = %{}

      expect(TestSource, :fetch_exchange_rate, fn "failed-ticker" -> {:ok, %Rate{}} end)
      set_mox_global()

      assert {:noreply, ^state} =
               ExchangeRates.handle_info({nil, {ticker, {:error, "some error"}}}, state)

      assert_receive {_, {^ticker, {:ok, _}}}
    end
  end

  test "all_tickers/0" do
    ExchangeRates.init([])

    rates = [
      %Rate{id: "z", symbol: "z"},
      %Rate{id: "a", symbol: "a"}
    ]

    expected_rates = Enum.reverse(rates)
    for rate <- rates, do: :ets.insert(ExchangeRates.table_name(), {rate.id, rate})

    assert expected_rates == ExchangeRates.all_tickers()
  end
end
