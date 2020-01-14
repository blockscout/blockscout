defmodule Indexer.Fetcher.CoinBalanceOnDemandTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Wei
  alias Explorer.Counters.AverageBlockTime
  alias Indexer.Fetcher.CoinBalanceOnDemand

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)
    start_supervised!({CoinBalanceOnDemand, [mocked_json_rpc_named_arguments, [name: CoinBalanceOnDemand]]})

    Application.put_env(:explorer, AverageBlockTime, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false)
    end)

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "trigger_fetch/1" do
    setup do
      now = Timex.now()

      # we space these very far apart so that we know it will consider the 0th block stale (it calculates how far
      # back we'd need to go to get 24 hours in the past)
      Enum.each(0..100, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(101 - i) * 50))
      end)

      insert(:block, number: 101, timestamp: now)
      AverageBlockTime.refresh()

      stale_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 100)
      current_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 101)

      pending_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 101)
      insert(:unfetched_balance, address_hash: pending_address.hash, block_number: 102)

      %{stale_address: stale_address, current_address: current_address, pending_address: pending_address}
    end

    test "treats all addresses as current if the average block time is disabled", %{stale_address: address} do
      Application.put_env(:explorer, AverageBlockTime, enabled: false)

      assert CoinBalanceOnDemand.trigger_fetch(address) == :current
    end

    test "if the address has not been fetched within the last 24 hours of blocks it is considered stale", %{
      stale_address: address
    } do
      assert CoinBalanceOnDemand.trigger_fetch(address) == {:stale, 101}
    end

    test "if the address has been fetched within the last 24 hours of blocks it is considered current", %{
      current_address: address
    } do
      assert CoinBalanceOnDemand.trigger_fetch(address) == :current
    end

    test "if there is an unfetched balance within the window for an address, it is considered pending", %{
      pending_address: pending_address
    } do
      assert CoinBalanceOnDemand.trigger_fetch(pending_address) == {:pending, 102}
    end
  end

  describe "update behaviour" do
    setup do
      Subscriber.to(:addresses, :on_demand)
      Subscriber.to(:address_coin_balances, :on_demand)

      now = Timex.now()

      # we space these very far apart so that we know it will consider the 0th block stale (it calculates how far
      # back we'd need to go to get 24 hours in the past)
      Enum.each(0..100, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(101 - i) * 50))
      end)

      insert(:block, number: 101, timestamp: now)
      AverageBlockTime.refresh()

      :ok
    end

    test "a stale address broadcasts the new address" do
      address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 100)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                     %{
                                                       id: id,
                                                       method: "eth_getBalance",
                                                       params: [^string_address_hash, "0x65"]
                                                     }
                                                   ],
                                                   _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x02"}]}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(address) == {:stale, 101}

      {:ok, expected_wei} = Wei.cast(2)

      assert_receive(
        {:chain_event, :addresses, :on_demand,
         [%{hash: ^address_hash, fetched_coin_balance: ^expected_wei, fetched_coin_balance_block_number: 101}]}
      )
    end

    test "a pending address broadcasts the new address and the new coin balance" do
      address = insert(:address, fetched_coin_balance: 0, fetched_coin_balance_block_number: 101)
      insert(:unfetched_balance, address_hash: address.hash, block_number: 102)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                     %{
                                                       id: id,
                                                       method: "eth_getBalance",
                                                       params: [^string_address_hash, "0x66"]
                                                     }
                                                   ],
                                                   _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x02"}]}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(address) == {:pending, 102}

      {:ok, expected_wei} = Wei.cast(2)

      assert_receive(
        {:chain_event, :addresses, :on_demand,
         [%{hash: ^address_hash, fetched_coin_balance: ^expected_wei, fetched_coin_balance_block_number: 102}]}
      )
    end
  end
end
