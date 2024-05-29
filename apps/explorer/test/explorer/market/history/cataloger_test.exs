defmodule Explorer.Market.History.CatalogerTest do
  use Explorer.DataCase, async: false

  import Mox
  import Ecto.Query, only: [order_by: 2]

  alias Explorer.Market.MarketHistory
  alias Explorer.Market.History.Cataloger
  alias Explorer.Market.History.Source.Price.TestSource
  alias Explorer.Market.History.Source.Price.CryptoCompare
  alias Explorer.Repo
  alias Plug.Conn

  setup do
    Application.put_env(:explorer, Cataloger, source: TestSource)
    Application.put_env(:explorer, Cataloger, enabled: true)
    :ok
  end

  test "init" do
    assert {:ok, %{}} == Cataloger.init(:ok)
    assert_received {:fetch_price_history, 365}
  end

  test "handle_info with `{:fetch_price_history, days}`" do
    bypass = Bypass.open()
    Application.put_env(:explorer, CryptoCompare, base_url: "http://localhost:#{bypass.port}")

    resp = """
    {
      "Response": "Success",
      "Type": 100,
      "Aggregated": false,
      "TimeTo": 1522569618,
      "TimeFrom": 1522566018,
      "FirstValueInArray": true,
      "ConversionType": {
        "type": "multiply",
        "conversionSymbol": "ETH"
      },
      "Data": [{
        "time": 1522566018,
        "high": 10,
        "low": 5,
        "open": 5,
        "volumefrom": 0,
        "volumeto": 0,
        "close": 10,
        "conversionType": "multiply",
        "conversionSymbol": "ETH"
      }],
      "RateLimit": {},
      "HasWarning": false
    }
    """

    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, resp) end)

    records = [
      %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5), secondary_coin: false}
    ]

    expect(TestSource, :fetch_price_history, fn 1, _ -> {:ok, records} end)
    set_mox_global()
    state = %{}

    assert {:noreply, state} == Cataloger.handle_info({:fetch_price_history, 1}, state)
    assert_receive {_ref, {:price_history, {1, 0, false, {:ok, ^records}}}}
  end

  test "handle_info with successful tasks (price, market cap and tvl)" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)

    price_records = [
      %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)},
      %{date: ~D[2018-04-02], closing_price: Decimal.new(6), opening_price: Decimal.new(2)}
    ]

    market_cap_records = [%{date: ~D[2018-04-01], market_cap: Decimal.new(100_500)}]
    tvl_records = [%{date: ~D[2018-04-01], tvl: Decimal.new(200_500)}]

    state = %{
      price_records: price_records
    }

    state2 = Map.put(state, :market_cap_records, market_cap_records)

    assert {:noreply, state} ==
             Cataloger.handle_info({nil, {:price_history, {1, 0, false, {:ok, price_records}}}}, state)

    assert_receive {:fetch_market_cap_history, 1}

    assert {:noreply, state2} ==
             Cataloger.handle_info({nil, {:market_cap_history, {0, 3, {:ok, market_cap_records}}}}, state)

    assert {:noreply, %{}} ==
             Cataloger.handle_info({nil, {:tvl_history, {0, 3, {:ok, tvl_records}}}}, state2)

    assert record2 = Repo.get_by(MarketHistory, date: Enum.at(price_records, 1).date)
    assert record1 = Repo.get_by(MarketHistory, date: Enum.at(price_records, 0).date)
    assert record2.closing_price == Decimal.new(6)
    assert record2.market_cap == nil
    assert record2.tvl == nil
    assert record1.closing_price == Decimal.new(10)
    assert record1.market_cap == Decimal.new(100_500)
    assert record1.tvl == Decimal.new(200_500)
  end

  test "handle_info with successful tasks (price and market cap)" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)
    price_records = [%{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}]
    market_cap_records = [%{date: ~D[2018-04-01], market_cap: Decimal.new(100_500)}]
    tvl_records = []

    state = %{
      price_records: price_records
    }

    state2 = Map.put(state, :market_cap_records, market_cap_records)

    assert {:noreply, state} ==
             Cataloger.handle_info({nil, {:price_history, {1, 0, false, {:ok, price_records}}}}, state)

    assert_receive {:fetch_market_cap_history, 1}

    assert {:noreply, state2} ==
             Cataloger.handle_info({nil, {:market_cap_history, {0, 3, {:ok, market_cap_records}}}}, state)

    assert {:noreply, %{}} ==
             Cataloger.handle_info({nil, {:tvl_history, {0, 3, {:ok, tvl_records}}}}, state2)

    assert record = Repo.get_by(MarketHistory, date: Enum.at(price_records, 0).date)
    assert record.opening_price == Decimal.new(5)
    assert record.market_cap == Decimal.new(100_500)
    assert record.tvl == nil
  end

  test "handle_info with successful price task" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)
    price_records = [%{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}]
    market_cap_records = []
    tvl_records = []

    state = %{
      price_records: price_records
    }

    state2 = Map.put(state, :market_cap_records, market_cap_records)

    assert {:noreply, state} ==
             Cataloger.handle_info({nil, {:price_history, {1, 0, false, {:ok, price_records}}}}, state)

    assert_receive {:fetch_market_cap_history, 1}

    assert {:noreply, state2} ==
             Cataloger.handle_info({nil, {:market_cap_history, {0, 3, {:ok, market_cap_records}}}}, state)

    assert {:noreply, %{}} ==
             Cataloger.handle_info({nil, {:tvl_history, {0, 3, {:ok, tvl_records}}}}, state2)

    assert record = Repo.get_by(MarketHistory, date: Enum.at(price_records, 0).date)
    assert record.closing_price == Decimal.new(10)
    assert record.market_cap == nil
    assert record.tvl == nil
  end

  test "current day values are saved in state" do
    bypass = Bypass.open()
    Application.put_env(:explorer, CryptoCompare, base_url: "http://localhost:#{bypass.port}")
    old_env = Application.get_all_env(:explorer)

    Application.put_env(:explorer, Explorer.History.Process, base_backoff: 0)

    resp =
      &"""
      {
        "Response": "Success",
        "Type": 100,
        "Aggregated": false,
        "TimeTo": 1522569618,
        "TimeFrom": 1522566018,
        "FirstValueInArray": true,
        "ConversionType": {
          "type": "multiply",
          "conversionSymbol": "ETH"
        },
        "Data": [{
          "time": #{&1},
          "high": 10,
          "low": 5,
          "open": 5,
          "volumefrom": 0,
          "volumeto": 0,
          "close": #{&2},
          "conversionType": "multiply",
          "conversionSymbol": "ETH"
        }],
        "RateLimit": {},
        "HasWarning": false
      }
      """

    Bypass.expect(bypass, fn conn ->
      case conn.params["limit"] do
        "365" -> Conn.resp(conn, 200, resp.(1_522_566_018, 10))
        _ -> Conn.resp(conn, 200, resp.(1_522_633_818, 20))
      end
    end)

    {:ok, pid} = Cataloger.start_link([])

    :timer.sleep(5000)

    Process.send(pid, {:fetch_price_history, 1}, [])

    :timer.sleep(5000)

    assert [
             %Explorer.Market.MarketHistory{
               date: ~D[2018-04-01]
             } = first_entry,
             %Explorer.Market.MarketHistory{
               date: ~D[2018-04-02]
             } = second_entry
           ] = MarketHistory |> order_by(asc: :date) |> Repo.all()

    assert Decimal.eq?(first_entry.closing_price, Decimal.new(10))
    assert Decimal.eq?(second_entry.closing_price, Decimal.new(20))

    Application.put_all_env(explorer: old_env)
  end

  test "handle info for DOWN message" do
    assert {:noreply, %{}} == Cataloger.handle_info({:DOWN, nil, :process, nil, nil}, %{})
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = Cataloger.start_link([])
  end
end
