defmodule EthereumJSONRPC.RequestCoordinatorTest do
  use ExUnit.Case
  use EthereumJSONRPC.Case

  alias EthereumJSONRPC.RollingWindow
  alias EthereumJSONRPC.RequestCoordinator

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  defp sleep_time(timeouts) do
    wait_per_timeout =
      :ethereum_jsonrpc
      |> Application.get_env(RequestCoordinator)
      |> Keyword.fetch!(:wait_per_timeout)

    timeouts * wait_per_timeout
  end

  setup do
    table = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator)[:rolling_window_opts][:table]

    :ets.delete_all_objects(table)

    %{table: table}
  end

  test "rolling window increments on timeout", %{table: table} do
    expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:error, :timeout} end)

    RequestCoordinator.perform(%{}, EthereumJSONRPC.Mox, [], :timer.minutes(60))

    assert RollingWindow.count(table, :timeout) == 1
  end

  test "waits the configured amount of time per failure", %{table: table} do
    RollingWindow.inc(table, :timeout)
    RollingWindow.inc(table, :timeout)
    RollingWindow.inc(table, :timeout)
    RollingWindow.inc(table, :timeout)
    RollingWindow.inc(table, :timeout)
    RollingWindow.inc(table, :timeout)

    test_process = self()

    expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
      send(test_process, :called_json_rpc)
    end)

    # Calculate expected sleep time as if there were one less failure, allowing
    # a margin of error between the refute_receive, assert_receive, and actual
    # call.
    wait_time = sleep_time(5)

    Task.async(fn ->
      RequestCoordinator.perform(%{}, EthereumJSONRPC.Mox, [], :timer.minutes(60))
    end)

    refute_receive(:called_json_rpc, wait_time)

    assert_receive(:called_json_rpc, wait_time)
  end
end
