defmodule Explorer.Market.History.CatalogerTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Market.MarketHistory
  alias Explorer.Market.History.Cataloger
  alias Explorer.Market.History.Source.TestSource
  alias Explorer.Repo

  setup do
    Application.put_env(:explorer, Cataloger, source: TestSource)
    :ok
  end

  test "init" do
    assert {:ok, %{}} == Cataloger.init(:ok)
    assert_received {:fetch_history, 365}
  end

  test "handle_info with `{:fetch_history, days}`" do
    records = [%{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}]
    expect(TestSource, :fetch_history, fn 1 -> {:ok, records} end)
    set_mox_global()
    state = %{}

    assert {:noreply, state} == Cataloger.handle_info({:fetch_history, 1}, state)
    assert_receive {_ref, {1, 0, {:ok, ^records}}}
  end

  test "handle_info with successful task" do
    Application.put_env(:explorer, Cataloger, history_fetch_interval: 1)
    record = %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}
    state = %{}

    assert {:noreply, state} == Cataloger.handle_info({nil, {1, 0, {:ok, [record]}}}, state)
    assert_receive {:fetch_history, 1}
    assert Repo.get_by(MarketHistory, date: record.date)
  end

  test "handle info for DOWN message" do
    assert {:noreply, %{}} == Cataloger.handle_info({:DOWN, nil, :process, nil, nil}, %{})
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = Cataloger.start_link([])
  end
end
