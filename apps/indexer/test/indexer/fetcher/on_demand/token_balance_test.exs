defmodule Indexer.Fetcher.OnDemand.TokenBalanceTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Indexer.Fetcher.OnDemand.TokenBalance, as: TokenBalanceOnDemand

  setup :set_mox_global
  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)

    configuration = Application.get_env(:indexer, TokenBalanceOnDemand.Supervisor)
    Application.put_env(:indexer, TokenBalanceOnDemand.Supervisor, disabled?: false)

    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    TokenBalanceOnDemand.Supervisor.Case.start_supervised!(json_rpc_named_arguments: mocked_json_rpc_named_arguments)

    on_exit(fn ->
      Application.put_env(:indexer, TokenBalanceOnDemand.Supervisor, configuration)
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "update behaviour" do
    setup do
      Subscriber.to(:address_current_token_balances, :on_demand)
      Subscriber.to(:address_token_balances, :on_demand)

      now = Timex.now()

      Enum.each(0..101, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(102 - i) * 50))
      end)

      insert(:block, number: 102, timestamp: now)
      AverageBlockTime.refresh()

      :ok
    end

    test "current token balances are imported and broadcasted for a stale address" do
      %{address: address, token_contract_address_hash: token_contract_address_hash} =
        insert(:address_current_token_balance,
          value_fetched_at: nil,
          value: nil,
          token_type: "ERC-20",
          block_number: 101
        )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      TokenBalanceOnDemand.trigger_fetch(address.hash)

      Process.sleep(100)

      [%{value: updated_value} = updated_ctb] = Repo.all(CurrentTokenBalance)

      assert updated_value == Decimal.new(1_000_000_000_000_000_000_000_000)
      refute is_nil(updated_ctb.value_fetched_at)

      address_hash = to_string(address.hash)

      assert_receive(
        {:chain_event, :address_current_token_balances, :on_demand,
         %{
           address_hash: ^address_hash,
           address_current_token_balances: [
             %{value: ^updated_value, token_contract_address_hash: ^token_contract_address_hash}
           ]
         }}
      )
    end

    test "historic balances are imported and broadcasted" do
      token_balance = insert(:token_balance, value_fetched_at: nil, value: nil, token_type: "ERC-20", block_number: 101)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      TokenBalanceOnDemand.trigger_historic_fetch(
        token_balance.address_hash,
        token_balance.token_contract_address_hash,
        token_balance.token_type,
        token_balance.token_id,
        token_balance.block_number
      )

      Process.sleep(100)

      [%{value: updated_value} = updated_tb] = Repo.all(TokenBalance)

      assert updated_value == Decimal.new(1_000_000_000_000_000_000_000_000)
      refute is_nil(updated_tb.value_fetched_at)

      address_hash = token_balance.address_hash
      token_contract_address_hash = token_balance.token_contract_address_hash

      assert_receive(
        {:chain_event, :address_token_balances, :on_demand,
         [
           %{
             address_hash: ^address_hash,
             token_contract_address_hash: ^token_contract_address_hash,
             value: ^updated_value
           }
         ]}
      )
    end
  end

  describe "run/2" do
    setup do
      now = Timex.now()

      Enum.each(0..101, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(102 - i) * 50))
      end)

      insert(:block, number: 102, timestamp: now)
      AverageBlockTime.refresh()

      :ok
    end

    test "fetches token balance for an address" do
      address = insert(:address, hash: "0x3078000000000000000000000000000000000001")
      token_contract_address = insert(:address, hash: "0x3078000000000000000000000000000000000002")

      token =
        insert(:token,
          contract_address_hash: token_contract_address.hash,
          contract_address: token_contract_address
        )

      insert(:address_current_token_balance,
        address_hash: address.hash,
        address: address,
        token_contract_address_hash: token_contract_address.hash,
        token: token,
        token_type: "ERC-20",
        value_fetched_at: nil,
        value: nil
      )

      insert_list(2, :block)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      assert TokenBalanceOnDemand.run(
               [{:fetch, address.hash}],
               nil
             ) == :ok

      token_balance_updated = Repo.get_by(CurrentTokenBalance, address_hash: address.hash)

      assert token_balance_updated.value == Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value_fetched_at != nil
    end
  end
end
