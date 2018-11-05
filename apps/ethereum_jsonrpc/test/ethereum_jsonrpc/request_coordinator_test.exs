defmodule EthereumJSONRPC.RequestCoordinatorTest do
  use ExUnit.Case
  use EthereumJSONRPC.Case

  import Mox

  alias EthereumJSONRPC.RollingWindow
  alias EthereumJSONRPC.RequestCoordinator

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    table = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator)[:rolling_window_opts][:table]

    :ets.delete_all_objects(table)

    %{table: table}
  end

  describe "perform/4" do
    test "forwards result whenever a request doesn't timeout", %{table: table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:ok, %{}} end)
      assert RollingWindow.count(table, :throttleable_error_count) == 0
      assert {:ok, %{}} == RequestCoordinator.perform(%{}, EthereumJSONRPC.Mox, [], :timer.minutes(60))
      assert RollingWindow.count(table, :throttleable_error_count) == 0
    end

    test "increments counter on certain errors", %{table: table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn :timeout, _ -> {:error, :timeout} end)
      expect(EthereumJSONRPC.Mox, :json_rpc, fn :bad_gateway, _ -> {:error, {:bad_gateway, "message"}} end)

      assert {:error, :timeout} == RequestCoordinator.perform(:timeout, EthereumJSONRPC.Mox, [], :timer.minutes(60))
      assert RollingWindow.count(table, :throttleable_error_count) == 1

      assert {:error, {:bad_gateway, "message"}} ==
               RequestCoordinator.perform(:bad_gateway, EthereumJSONRPC.Mox, [], :timer.minutes(60))

      assert RollingWindow.count(table, :throttleable_error_count) == 2
    end

    test "returns timeout error if sleep time will exceed max timeout", %{table: table} do
      expect(EthereumJSONRPC.Mox, :json_rpc, 0, fn _, _ -> :ok end)
      RollingWindow.inc(table, :throttleable_error_count)
      assert {:error, :timeout} == RequestCoordinator.perform(%{}, EthereumJSONRPC.Mox, [], 1)
    end
  end
end
