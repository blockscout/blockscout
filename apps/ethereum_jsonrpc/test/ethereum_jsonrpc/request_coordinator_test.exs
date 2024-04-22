defmodule EthereumJSONRPC.RequestCoordinatorTest do
  use ExUnit.Case
  use EthereumJSONRPC.Case

  import Mox

  alias EthereumJSONRPC.RollingWindow
  alias EthereumJSONRPC.RequestCoordinator

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    timeout_table =
      Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator)[:rolling_window_opts][:table]

    throttle_table =
      Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator)[:throttle_rolling_window_opts][:table]

    :ets.delete_all_objects(timeout_table)
    :ets.delete_all_objects(throttle_table)

    %{timeout_table: timeout_table, throttle_table: throttle_table}
  end

  describe "perform/4" do
    test "forwards result whenever a request doesn't timeout", %{timeout_table: timeout_table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:ok, %{}} end)
      assert RollingWindow.count(timeout_table, :throttleable_error_count_eth_call) == 0

      assert {:ok, %{}} ==
               RequestCoordinator.perform(%{method: "eth_call"}, EthereumJSONRPC.Mox, [], :timer.minutes(60))

      assert RollingWindow.count(timeout_table, :throttleable_error_count_eth_call) == 0
    end

    test "increments counter on certain errors", %{timeout_table: timeout_table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{method: "timeout"}, _ -> {:error, :timeout} end)
      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{method: "bad_gateway"}, _ -> {:error, {:bad_gateway, "message"}} end)

      assert {:error, :timeout} ==
               RequestCoordinator.perform(%{method: "timeout"}, EthereumJSONRPC.Mox, [], :timer.minutes(60))

      assert RollingWindow.count(timeout_table, :throttleable_error_count_timeout) == 1
      assert RollingWindow.count(timeout_table, :throttleable_error_count_bad_gateway) == 0

      assert {:error, {:bad_gateway, "message"}} ==
               RequestCoordinator.perform(%{method: "bad_gateway"}, EthereumJSONRPC.Mox, [], :timer.minutes(60))

      assert RollingWindow.count(timeout_table, :throttleable_error_count_timeout) == 1
      assert RollingWindow.count(timeout_table, :throttleable_error_count_bad_gateway) == 1
    end

    test "returns timeout error if sleep time will exceed max timeout", %{timeout_table: timeout_table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, 0, fn _, _ -> :ok end)
      RollingWindow.inc(timeout_table, :throttleable_error_count_eth_call)
      assert {:error, :timeout} == RequestCoordinator.perform(%{method: "eth_call"}, EthereumJSONRPC.Mox, [], 1)
    end

    test "increments throttle_table even when not an error", %{throttle_table: throttle_table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:ok, %{}} end)
      assert RollingWindow.count(throttle_table, :throttle_requests_count) == 0
      assert {:ok, %{}} == RequestCoordinator.perform(%{}, EthereumJSONRPC.Mox, [], :timer.minutes(60))
      assert RollingWindow.count(throttle_table, :throttle_requests_count) == 1
    end
  end
end
