defmodule Explorer.Market.History.CatalogerTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Market.MarketHistory
  alias Explorer.Market.History.Cataloger
  alias Explorer.Market.History.Source.Price.TestSource
  alias Explorer.Repo

  setup do
    Application.put_env(:explorer, Cataloger, source: TestSource)
    :ok
  end

  test "init" do
    assert {:ok, %{}} == Cataloger.init(:ok)
    assert_received {:fetch_price_history, 365}
  end

  test "handle_info with `{:fetch_price_history, days}`" do
    records = [%{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}]
    expect(TestSource, :fetch_price_history, fn 1 -> {:ok, records} end)
    set_mox_global()
    state = %{}

    assert {:noreply, state} == Cataloger.handle_info({:fetch_price_history, 1}, state)
    assert_receive {_ref, {:price_history, {1, 0, {:ok, ^records}}}}
  end

  test "handle_info with successful tasks (price and market cap)" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)
    record_price = %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}
    record_market_cap = %{date: ~D[2018-04-01], market_cap: Decimal.new(100_500)}

    state = %{
      price_records: [
        record_price
      ]
    }

    assert {:noreply, state} == Cataloger.handle_info({nil, {:price_history, {1, 0, {:ok, [record_price]}}}}, state)
    assert_receive :fetch_market_cap_history

    assert {:noreply, state} ==
             Cataloger.handle_info({nil, {:market_cap_history, {0, {:ok, record_market_cap}}}}, state)

    assert Repo.get_by(MarketHistory, date: record_price.date)
  end

  test "handle_info with successful price task" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)
    record_price = %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}
    record_market_cap = nil

    state = %{
      price_records: [
        record_price
      ]
    }

    assert {:noreply, state} == Cataloger.handle_info({nil, {:price_history, {1, 0, {:ok, [record_price]}}}}, state)
    assert_receive :fetch_market_cap_history

    assert {:noreply, state} ==
             Cataloger.handle_info({nil, {:market_cap_history, {0, {:ok, record_market_cap}}}}, state)

    assert record = Repo.get_by(MarketHistory, date: record_price.date)
    assert record.market_cap == nil
  end

  test "handle info for DOWN message" do
    assert {:noreply, %{}} == Cataloger.handle_info({:DOWN, nil, :process, nil, nil}, %{})
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = Cataloger.start_link([])
  end
end
