defmodule Explorer.History.ProcessTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.History.TestHistorian

  setup do
    Application.put_env(:explorer, TestHistorian,
      init_lag: 0,
      days_to_compile_at_init: nil
    )
  end

  describe "init/1" do
    test "sends compile_historical_records with no init_lag" do
      assert {:ok, %{:historian => TestHistorian}} = HistoryProcess.init([:ok, TestHistorian])
      assert_receive {:compile_historical_records, 365}
    end

    test "sends compile_historical_records after some init_lag" do
      Application.put_env(:explorer, TestHistorian, init_lag: 200)
      assert {:ok, %{:historian => TestHistorian}} = HistoryProcess.init([:ok, TestHistorian])
      refute_receive {:compile_historical_records, 365}, 150
      assert_receive {:compile_historical_records, 365}
    end

    test "sends compile_historical_records with configurable number of days" do
      Application.put_env(:explorer, TestHistorian, days_to_compile_at_init: 30)
      assert {:ok, %{:historian => TestHistorian}} = HistoryProcess.init([:ok, TestHistorian])
      assert_receive {:compile_historical_records, 30}
    end
  end

  test "handle_info with `{:compile_historical_records, days}`" do
    records = [%{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}]

    TestHistorian
    |> expect(:compile_records, fn 1 -> {:ok, records} end)
    |> expect(:save_records, fn _ -> :ok end)

    set_mox_global()

    state = %{historian: TestHistorian}

    assert {:noreply, ^state} = HistoryProcess.handle_info({:compile_historical_records, 1}, state)
    assert_receive {_ref, {1, 0, {:ok, ^records}}}
  end

  test "handle_info with successful task" do
    record = %{date: ~D[2018-04-01], closing_price: Decimal.new(10), opening_price: Decimal.new(5)}

    TestHistorian
    |> expect(:compile_records, fn 1 -> {:ok, [record]} end)
    |> expect(:save_records, fn _ -> :ok end)

    state = %{historian: TestHistorian}

    # interval should be short enough that it doesn't slow down testing...
    # ...but long enough to detect. 16ms should be detectable on the slowest dev machines
    history_fetch_interval = 16

    Application.put_env(:explorer, HistoryProcess, history_fetch_interval: history_fetch_interval)

    assert {:noreply, state} == HistoryProcess.handle_info({nil, {1, 0, {:ok, [record]}}}, state)

    # Message isn't sent before interval is up
    refute_receive {:compile_historical_records, 1}, history_fetch_interval - 1

    # Now message is sent
    assert_receive {:compile_historical_records, 1}
  end

  test "handle_info with failed task" do
    TestHistorian
    |> expect(:compile_records, fn 1 -> :error end)
    |> expect(:save_records, fn _ -> :ok end)

    # Process will restart, so this is needed
    set_mox_global()

    state = %{historian: TestHistorian}

    # base_backoff should be short enough that it doesn't slow down testing...
    # ...but long enough to detect. 16ms should be detectable on the slowest dev machines
    base_backoff = 16

    Application.put_env(:explorer, HistoryProcess, base_backoff: base_backoff)

    assert {:noreply, state} == HistoryProcess.handle_info({nil, {1, 0, :error}}, state)

    # Message isn't sent before interval is up
    refute_receive {_ref, {1, 1, :error}}, base_backoff - 1

    # Now message is sent
    assert_receive {_ref, {1, 1, :error}}
  end

  test "handle info for DOWN message" do
    assert {:noreply, %{}} == HistoryProcess.handle_info({:DOWN, nil, :process, nil, nil}, %{})
  end
end
