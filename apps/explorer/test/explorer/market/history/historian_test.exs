defmodule Explorer.Market.History.CatalogerTest do
  use Explorer.DataCase, async: false

  alias Explorer.Market.MarketHistory
  alias Explorer.Market.History.Historian
  alias Explorer.Market.History.Source.TestSource
  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.Repo

  setup do
    Application.put_env(:explorer, Historian, source: TestSource)
    :ok
  end

  test "handle_info with successful task" do
    Application.put_env(:explorer, HistoryProcess, history_fetch_interval: 1)
    record = %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}
    state = %{historian: Historian}

    assert {:noreply, state} == HistoryProcess.handle_info({nil, {1, 0, {:ok, [record]}}}, state)
    assert_receive {:compile_historical_records, 1}
    assert Repo.get_by(MarketHistory, date: record.date)
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = Historian.start_link([])
  end
end
