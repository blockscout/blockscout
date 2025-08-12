defmodule Explorer.Market.Fetcher.HistoryTest do
  use Explorer.DataCase, async: false

  import Mox
  import Ecto.Query, only: [limit: 2, order_by: 2]

  alias Explorer.Market.{MarketHistory, Source}
  alias Explorer.Market.Fetcher.History
  alias Explorer.Market.Source.TestSource
  alias Explorer.Market.Source.CryptoCompare
  alias Explorer.Repo
  alias Plug.Conn

  setup do
    source_configuration = Application.get_env(:explorer, Source)
    history_configuration = Application.get_env(:explorer, History)

    Application.put_env(:explorer, Source, native_coin_history_source: TestSource)

    Application.put_env(
      :explorer,
      History,
      Keyword.merge(history_configuration, enabled: true, history_fetch_interval: 0)
    )

    on_exit(fn ->
      Application.put_env(:explorer, Source, source_configuration)
      Application.put_env(:explorer, History, history_configuration)
    end)

    :ok
  end

  test "init" do
    assert {:ok, %{types_states: states}} = History.init(:ok)
    assert_received {:fetch_all, 365}

    assert Map.has_key?(states, :native_coin_price_history)
    assert Map.has_key?(states, :secondary_coin_price_history)
    assert Map.has_key?(states, :market_cap_history)
    assert Map.has_key?(states, :tvl_history)

    assert %{
             source: TestSource,
             max_failed_attempts: 10,
             failed_attempts: 0,
             finished?: false,
             records: []
           } = states.native_coin_price_history
  end

  test "handle_info with native_coin_price_history" do
    source_configuration = Application.get_env(:explorer, Source)
    crypto_compare_configuration = Application.get_env(:explorer, CryptoCompare)

    bypass = Bypass.open()

    Application.put_env(:explorer, Source, native_coin_history_source: CryptoCompare)
    Application.put_env(:explorer, CryptoCompare, base_url: "http://localhost:#{bypass.port}", coin_symbol: "TEST")
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Source, source_configuration)
      Application.put_env(:explorer, CryptoCompare, crypto_compare_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    resp =
      """
      {
        "Response": "Success",
        "Message": "",
        "HasWarning": false,
        "Type": 100,
        "RateLimit": {},
        "Data": {
          "Aggregated": false,
          "TimeFrom": 1739318400,
          "TimeTo": 1739491200,
          "Data": [
            {
              "time": 1522566018,
              "high": 10229.02,
              "low": 9666.32,
              "open": 5,
              "volumefrom": 91397.18,
              "volumeto": 916559418.68,
              "close": 10,
              "conversionType": "multiply",
              "conversionSymbol": "BTC"
            }
          ]
        }
      }
      """

    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, resp) end)

    state = %{
      types_states: %{
        native_coin_price_history: %{
          source: CryptoCompare,
          max_failed_attempts: 10,
          failed_attempts: 0,
          finished?: false,
          records: []
        }
      },
      day_count: 1
    }

    records = [
      %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5), secondary_coin: false}
    ]

    assert {:noreply, state} == History.handle_info(:native_coin_price_history, state)
    assert_receive {_ref, {:native_coin_price_history, {:ok, ^records}}}
  end

  test "handle_info with successful tasks" do
    price_records = [
      %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)},
      %{date: ~D[2018-04-02], closing_price: Decimal.new(6), opening_price: Decimal.new(2)}
    ]

    market_cap_records = [%{date: ~D[2018-04-01], market_cap: Decimal.new(100_500)}]
    tvl_records = [%{date: ~D[2018-04-01], tvl: Decimal.new(200_500)}]

    state = %{
      types_states: %{
        native_coin_price_history: %{
          source: TestSource,
          max_failed_attempts: 10,
          failed_attempts: 0,
          finished?: false,
          records: []
        },
        secondary_coin_price_history: %{
          source: nil,
          max_failed_attempts: 10,
          failed_attempts: 0,
          finished?: true,
          records: []
        },
        market_cap_history: %{
          source: TestSource,
          max_failed_attempts: 3,
          failed_attempts: 0,
          finished?: false,
          records: []
        },
        tvl_history: %{
          source: TestSource,
          max_failed_attempts: 3,
          failed_attempts: 0,
          finished?: false,
          records: []
        }
      },
      day_count: 1
    }

    assert {:noreply, new_state} =
             History.handle_info({nil, {:native_coin_price_history, {:ok, price_records}}}, state)

    assert get_in(new_state.types_states, [:native_coin_price_history, :finished?])
    assert get_in(new_state.types_states, [:native_coin_price_history, :records]) == price_records

    assert {:noreply, new_state} =
             History.handle_info({nil, {:market_cap_history, {:ok, market_cap_records}}}, new_state)

    assert get_in(new_state.types_states, [:market_cap_history, :finished?])
    assert get_in(new_state.types_states, [:market_cap_history, :records]) == market_cap_records

    assert {:noreply, final_state} =
             History.handle_info({nil, {:tvl_history, {:ok, tvl_records}}}, new_state)

    assert record2 = Repo.get_by(MarketHistory, date: Enum.at(price_records, 1).date)
    assert record1 = Repo.get_by(MarketHistory, date: Enum.at(price_records, 0).date)
    assert record2.closing_price == Decimal.new(6)
    assert record2.market_cap == nil
    assert record2.tvl == nil
    assert record1.closing_price == Decimal.new(10)
    assert record1.market_cap == Decimal.new(100_500)
    assert record1.tvl == Decimal.new(200_500)
  end

  test "current day values are saved in state" do
    bypass = Bypass.open()
    crypto_compare_configuration = Application.get_env(:explorer, CryptoCompare)
    source_configuration = Application.get_env(:explorer, Source)

    Application.put_env(:explorer, Source, native_coin_history_source: CryptoCompare)
    Application.put_env(:explorer, CryptoCompare, base_url: "http://localhost:#{bypass.port}", coin_symbol: "TEST")
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, CryptoCompare, crypto_compare_configuration)
      Application.put_env(:explorer, Source, source_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    resp =
      &"""
      {
        "Response": "Success",
        "Message": "",
        "HasWarning": false,
        "Type": 100,
        "RateLimit": {},
        "Data": {
          "Aggregated": false,
          "TimeFrom": 1739318400,
          "TimeTo": 1739491200,
          "Data": [
            {
              "time": #{&1},
              "high": 10229.02,
              "low": 9666.32,
              "open": 1.1,
              "volumefrom": 91397.18,
              "volumeto": 916559418.68,
              "close": #{&2},
              "conversionType": "multiply",
              "conversionSymbol": "BTC"
            }
          ]
        }
      }
      """

    Bypass.expect(bypass, fn conn ->
      case conn.params["limit"] do
        "365" -> Conn.resp(conn, 200, resp.(1_522_566_018, 10))
        _ -> Conn.resp(conn, 200, resp.(1_522_633_818, 20))
      end
    end)

    {:ok, pid} = History.start_link([])

    :timer.sleep(500)

    assert [
             %Explorer.Market.MarketHistory{
               date: ~D[2018-04-01]
             } = first_entry,
             %Explorer.Market.MarketHistory{
               date: ~D[2018-04-02]
             } = second_entry
           ] = MarketHistory |> order_by(asc: :date) |> limit(2) |> Repo.all()

    assert Decimal.eq?(first_entry.closing_price, Decimal.new(10))
    assert Decimal.eq?(second_entry.closing_price, Decimal.new(20))
  end

  test "handle info for DOWN message" do
    assert {:noreply, %{}} == History.handle_info({:DOWN, nil, :process, nil, nil}, %{})
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = History.start_link([])
  end
end
