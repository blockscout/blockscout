defmodule Indexer.Fetcher.OnDemand.ContractCodeTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Utility.AddressContractCodeFetchAttempt
  alias Indexer.Fetcher.OnDemand.ContractCode, as: ContractCodeOnDemand

  @moduletag :capture_log

  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!({ContractCodeOnDemand, [mocked_json_rpc_named_arguments, [name: ContractCodeOnDemand]]})

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "update behaviour" do
    setup do
      Subscriber.to(:fetched_bytecode, :on_demand)

      :ok
    end

    test "address broadcasts fetched code" do
      address = insert(:address)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      contract_code = "0x6080"

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getCode",
                                  params: [^string_address_hash, "latest"]
                                }
                              ],
                              _ ->
        {:ok, [%{id: id, result: contract_code}]}
      end)

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(100)

      address = assert(Repo.get(Address, address_hash))
      refute is_nil(address.contract_code)

      assert is_nil(Repo.get(AddressContractCodeFetchAttempt, address_hash))

      assert_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, ^contract_code]})
    end

    test "don't run the update on the address with non-empty nonce" do
      address = insert(:address, nonce: 2)
      address_hash = address.hash

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(100)

      address = assert(Repo.get(Address, address_hash))
      assert is_nil(address.contract_code)

      attempts = Repo.get(AddressContractCodeFetchAttempt, address_hash)
      assert is_nil(attempts)

      refute_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, "0x"]})
    end

    test "updates address_contract_code_fetch_attempts table" do
      address = insert(:address)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getCode",
                                  params: [^string_address_hash, "latest"]
                                }
                              ],
                              _ ->
        {:ok, [%{id: id, result: "0x"}]}
      end)

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(100)

      address = assert(Repo.get(Address, address_hash))
      assert is_nil(address.contract_code)

      attempts = Repo.get(AddressContractCodeFetchAttempt, address_hash)
      assert attempts.retries_number == 1

      refute_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, "0x"]})
    end

    test "updates contract_code after 2nd attempt" do
      threshold = parse_time_env_var("CONTRACT_CODE_ON_DEMAND_FETCHER_THRESHOLD", "500ms")
      Application.put_env(:indexer, ContractCodeOnDemand, threshold: threshold)

      address = insert(:address)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getCode",
                                  params: [^string_address_hash, "latest"]
                                }
                              ],
                              _ ->
        {:ok, [%{id: id, result: "0x"}]}
      end)

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(100)

      address = assert(Repo.get(Address, address_hash))
      assert is_nil(address.contract_code)

      attempts = Repo.get(AddressContractCodeFetchAttempt, address_hash)
      assert attempts.retries_number == 1

      refute_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, "0x"]})

      contract_code = "0x6080"

      # try 2nd time before update threshold reached: nothing should be updated
      :timer.sleep(100)

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(50)

      address = assert(Repo.get(Address, address_hash))
      assert is_nil(address.contract_code)

      refute is_nil(Repo.get(AddressContractCodeFetchAttempt, address_hash))

      refute_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, ^contract_code]})

      # trying 3d time after update threshold reached: update is expected.
      :timer.sleep(1000)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getCode",
                                  params: [^string_address_hash, "latest"]
                                }
                              ],
                              _ ->
        {:ok, [%{id: id, result: contract_code}]}
      end)

      assert ContractCodeOnDemand.trigger_fetch(address) == :ok

      :timer.sleep(50)

      address = assert(Repo.get(Address, address_hash))
      refute is_nil(address.contract_code)

      assert is_nil(Repo.get(AddressContractCodeFetchAttempt, address_hash))

      assert_receive({:chain_event, :fetched_bytecode, :on_demand, [^address_hash, ^contract_code]})

      default_threshold = parse_time_env_var("CONTRACT_CODE_ON_DEMAND_FETCHER_THRESHOLD", "5s")
      Application.put_env(:indexer, ContractCodeOnDemand, threshold: default_threshold)
    end

    defp parse_time_env_var(env_var, default_value) do
      case env_var |> safe_get_env(default_value) |> String.downcase() |> Integer.parse() do
        {milliseconds, "ms"} -> milliseconds
        {hours, "h"} -> :timer.hours(hours)
        {minutes, "m"} -> :timer.minutes(minutes)
        {seconds, s} when s in ["s", ""] -> :timer.seconds(seconds)
        _ -> 0
      end
    end

    defp safe_get_env(env_var, default_value) do
      env_var
      |> System.get_env(default_value)
      |> case do
        "" -> default_value
        value -> value
      end
      |> to_string()
    end
  end
end
