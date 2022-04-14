defmodule Explorer.Celo.CoreContractCacheTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase, async: false

  import Mox
  alias Explorer.Celo.CoreContracts
  require Logger

  describe "is_core_contract_address?" do
    test "correctly checks addresses" do
      test_address = "0xheycoolteststringwheredidyoufindit"
      test_contract_identifier = "TestID"

      start_supervised(
        {CoreContracts,
         %{
           refresh_period: :timer.hours(1000),
           cache: %{test_contract_identifier => test_address}
         }}
      )

      assert CoreContracts.is_core_contract_address?(test_address)

      test_address = "0xnewaddresshey"
    end
  end

  setup :set_mox_global

  describe "refresh/0" do
    test "successful refresh fetches new addresses" do
      test_address = "0xheycoolteststringwheredidyoufindit"
      test_contract_identifier = "TestID"

      start_supervised(
        {CoreContracts,
         %{
           refresh_period: :timer.hours(1000),
           cache: %{test_contract_identifier => test_address}
         }}
      )

      start_supervised(
        {Task.Supervisor, name: Explorer.TaskSupervisor},
        id: Explorer.TaskSupervisor
      )

      result_address = "8888888888888888888888888888888888888888"

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, 2, fn
        [%{method: "eth_call"}], _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000" <> result_address
             }
           ]}
      end)

      CoreContracts.refresh()

      # waiting for completion of async blockchain calls
      :timer.sleep(100)

      # previous address should no longer be there due to refresh provding new address
      refute CoreContracts.is_core_contract_address?(test_address)

      # new address is now considered a core contract
      assert CoreContracts.is_core_contract_address?("0x" <> result_address)
      assert CoreContracts.contract_address(test_contract_identifier) == "0x" <> result_address
    end

    test "unsuccessful refresh does not prevent core contract recognition" do
      test_address = "0xheycoolteststringwheredidyoufindit"
      test_contract_identifier = "TestID"

      start_supervised(
        {CoreContracts,
         %{
           refresh_period: :timer.hours(1000),
           cache: %{test_contract_identifier => test_address}
         }}
      )

      start_supervised(
        {Task.Supervisor, name: Explorer.TaskSupervisor},
        id: Explorer.TaskSupervisor
      )

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, 2, fn
        [%{method: "eth_call"}], _options ->
          raise "oh darn this is a failure"
      end)

      CoreContracts.refresh()

      # waiting for completion of async blockchain calls
      :timer.sleep(100)

      # previous address should still be considered a core contract
      assert CoreContracts.is_core_contract_address?(test_address)
      assert CoreContracts.contract_address(test_contract_identifier) == test_address
    end
  end
end
