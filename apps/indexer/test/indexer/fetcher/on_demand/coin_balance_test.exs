defmodule Indexer.Fetcher.OnDemand.CoinBalanceTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Wei
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.TestHelper
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)

    configuration = Application.get_env(:indexer, Indexer.Fetcher.OnDemand.CoinBalance.Supervisor)
    Application.put_env(:indexer, Indexer.Fetcher.OnDemand.CoinBalance.Supervisor, disabled?: false)

    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    Indexer.Fetcher.OnDemand.CoinBalance.Supervisor.Case.start_supervised!(
      json_rpc_named_arguments: mocked_json_rpc_named_arguments
    )

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.OnDemand.CoinBalance.Supervisor, configuration)
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "trigger_fetch/1" do
    setup do
      now = Timex.now()

      # we space these very far apart so that we know it will consider the 0th block stale (it calculates how far
      # back we'd need to go to get 24 hours in the past)
      Enum.each(0..101, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(102 - i) * 50))
      end)

      insert(:block, number: 102, timestamp: now)
      AverageBlockTime.refresh()

      stale_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 101)
      current_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 102)

      pending_address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 102)
      insert(:unfetched_balance, address_hash: pending_address.hash, block_number: 103)

      %{stale_address: stale_address, current_address: current_address, pending_address: pending_address}
    end

    test "treats all addresses as current if the average block time is disabled", %{stale_address: address} do
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, []}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(address) == :current
    end

    test "if the address has not been fetched within the last 24 hours of blocks it is considered stale", %{
      stale_address: address
    } do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, []}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(address) == {:stale, 102}
    end

    test "if the address has been fetched within the last 24 hours of blocks it is considered current", %{
      current_address: address
    } do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, []}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(address) == :current
    end

    test "if there is an unfetched balance within the window for an address, it is considered pending", %{
      pending_address: pending_address
    } do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, []}
      end)

      assert CoinBalanceOnDemand.trigger_fetch(pending_address) == {:pending, 103}
    end
  end

  describe "trigger_historic_fetch/2" do
    test "fetches and imports balance for any block" do
      address = insert(:address)
      block = insert(:block)
      insert(:block)
      string_address_hash = to_string(address.hash)
      block_number = block.number
      string_block_number = integer_to_quantity(block_number)
      balance = 42
      assert nil == CoinBalance.get_coin_balance(address.hash, block_number)

      TestHelper.eth_get_balance_expectation(string_address_hash, string_block_number, integer_to_quantity(balance))

      TestHelper.eth_get_block_by_number_expectation(block_number)

      {:ok, expected_wei} = Wei.cast(balance)

      CoinBalanceOnDemand.trigger_historic_fetch(address.hash, block_number)

      :timer.sleep(1000)

      assert %{value: ^expected_wei} = CoinBalance.get_coin_balance(address.hash, block_number)
    end
  end

  describe "update behaviour" do
    setup do
      Subscriber.to(:addresses, :on_demand)
      Subscriber.to(:address_coin_balances, :on_demand)

      now = Timex.now()

      # we space these very far apart so that we know it will consider the 0th block stale (it calculates how far
      # back we'd need to go to get 24 hours in the past)
      Enum.each(0..101, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(102 - i) * 50))
      end)

      insert(:block, number: 102, timestamp: now)
      AverageBlockTime.refresh()

      :ok
    end

    test "a stale address broadcasts the new address" do
      address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 101)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      TestHelper.eth_get_balance_expectation(string_address_hash, "0x66", "0x02")

      assert CoinBalanceOnDemand.trigger_fetch(address) == {:stale, 102}

      {:ok, expected_wei} = Wei.cast(2)

      assert_receive(
        {:chain_event, :addresses, :on_demand,
         [%{hash: ^address_hash, fetched_coin_balance: ^expected_wei, fetched_coin_balance_block_number: 102}]}
      )
    end

    test "a pending address broadcasts the new address and the new coin balance" do
      address = insert(:address, fetched_coin_balance: 0, fetched_coin_balance_block_number: 102)
      insert(:unfetched_balance, address_hash: address.hash, block_number: 103)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      TestHelper.eth_get_balance_expectation(string_address_hash, "0x67", "0x02")

      TestHelper.eth_get_block_by_number_expectation(103)

      assert CoinBalanceOnDemand.trigger_fetch(address) == {:pending, 103}

      {:ok, expected_wei} = Wei.cast(2)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :addresses, :on_demand,
         [%{hash: ^address_hash, fetched_coin_balance: ^expected_wei, fetched_coin_balance_block_number: 103}]}
      )
    end
  end
end
