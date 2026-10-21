# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.TokenTotalSupplyTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Token
  alias Indexer.Fetcher.OnDemand.TokenTotalSupply, as: Fetcher

  @moduletag :capture_log

  @table :token_total_supply_on_demand
  @total_supply_selector "0x18160ddd"
  @total_supply_hex "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    initial_explorer_retries = Application.get_env(:explorer, :token_functions_reader_max_retries)
    initial_fetcher_config = Application.get_env(:indexer, Fetcher) || []

    Application.put_env(:explorer, :token_functions_reader_max_retries, 1)
    Application.put_env(:indexer, Fetcher, Keyword.merge(initial_fetcher_config, threshold: :timer.minutes(5)))

    on_exit(fn ->
      Application.put_env(:explorer, :token_functions_reader_max_retries, initial_explorer_retries)
      Application.put_env(:indexer, Fetcher, initial_fetcher_config)
    end)

    start_supervised!(Fetcher.Supervisor.child_spec([[max_concurrency: 1]]))
    Subscriber.to(:token_total_supply, :on_demand)

    %{max_block: BlockNumber.get_max()}
  end

  describe "trigger_fetch/2" do
    test "fetches, stores and broadcasts total supply of a stale token" do
      token = stale_token()
      hash = token.contract_address_hash
      expect_total_supply(to_string(hash), fn id -> {:ok, [%{id: id, result: @total_supply_hex}]} end)

      assert :ok = Fetcher.trigger_fetch(token)

      assert_receive {:chain_event, :token_total_supply, :on_demand, [%Token{contract_address_hash: ^hash} = updated]},
                     1_000

      assert Decimal.equal?(updated.total_supply, Decimal.new(1_000_000_000_000_000_000))

      reloaded = Repo.get_by!(Token, contract_address_hash: hash)
      assert Decimal.equal?(reloaded.total_supply, Decimal.new(1_000_000_000_000_000_000))
      assert reloaded.total_supply_updated_at_block == BlockNumber.get_max()

      wait_until(fn -> :ets.lookup(@table, key(token)) == [] end)
      assert %{running: running} = :sys.get_state(Fetcher)
      assert running == %{}
      assert :ets.lookup(@table, :slots) == [{:slots, 0}]
    end

    test "does not enqueue a token that is already in flight" do
      token = stale_token()
      expect_blocking_total_supply(to_string(token.contract_address_hash))

      assert :ok = Fetcher.trigger_fetch(token)
      assert_receive {:rpc, _}, 1_000
      assert_receive {:blocked, task_pid}, 1_000
      assert [{_key, :in_flight, _at}] = :ets.lookup(@table, key(token))

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      refute_receive {:rpc, _}, 100
      assert %{running: running} = :sys.get_state(Fetcher)
      assert map_size(running) == 1

      send(task_pid, :continue)
      assert_receive {:chain_event, :token_total_supply, :on_demand, [%Token{}]}, 1_000
    end

    test "does nothing for a fresh token", %{max_block: max_block} do
      token = insert(:token, total_supply_updated_at_block: max_block)

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      assert :ets.lookup(@table, key(token)) == []
      assert %{running: running} = :sys.get_state(Fetcher)
      assert running == %{}
      refute_receive {:rpc, _}, 100
    end

    test "does nothing for a never fetched token with skip_metadata" do
      token = insert(:token, total_supply_updated_at_block: nil, skip_metadata: true)

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      assert :ets.lookup(@table, key(token)) == []
      refute_receive {:rpc, _}, 100
    end

    test "records a failed attempt and backs off until the threshold passes" do
      token = stale_token()
      hash_string = to_string(token.contract_address_hash)

      expect_total_supply(hash_string, fn id ->
        {:ok, [%{id: id, error: %{code: -32015, message: "VM execution error"}}]}
      end)

      assert :ok = Fetcher.trigger_fetch(token)
      assert_receive {:rpc, ^hash_string}, 1_000

      wait_until(fn -> match?([{_key, :failed, _at}], :ets.lookup(@table, key(token))) end)
      [{_key, :failed, failed_at}] = :ets.lookup(@table, key(token))
      refute_receive {:chain_event, :token_total_supply, :on_demand, _}, 100

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      assert [{_key, :failed, ^failed_at}] = :ets.lookup(@table, key(token))
      refute_receive {:rpc, _}, 100

      # Expire the failure record and make sure the token is fetched again.
      :ets.insert(@table, {key(token), :failed, failed_at - :timer.minutes(5) - 1})
      expect_total_supply(hash_string, fn id -> {:ok, [%{id: id, result: @total_supply_hex}]} end)

      assert :ok = Fetcher.trigger_fetch(token)
      assert_receive {:chain_event, :token_total_supply, :on_demand, [%Token{}]}, 1_000
      wait_until(fn -> :ets.lookup(@table, key(token)) == [] end)
    end

    test "drops requests above the concurrency cap and lets them retry later" do
      token_a = stale_token()
      token_b = stale_token()
      hash_b_string = to_string(token_b.contract_address_hash)
      expect_blocking_total_supply(to_string(token_a.contract_address_hash))

      assert :ok = Fetcher.trigger_fetch(token_a)
      assert_receive {:blocked, task_pid}, 1_000

      assert :ok = Fetcher.trigger_fetch(token_b)
      sync()

      assert :ets.lookup(@table, key(token_b)) == []
      assert :ets.lookup(@table, :slots) == [{:slots, 1}]
      assert %{running: running} = :sys.get_state(Fetcher)
      assert map_size(running) == 1
      refute_receive {:rpc, ^hash_b_string}, 100

      send(task_pid, :continue)
      assert_receive {:chain_event, :token_total_supply, :on_demand, [%Token{}]}, 1_000
      wait_until(fn -> map_size(:sys.get_state(Fetcher).running) == 0 end)
      assert :ets.lookup(@table, :slots) == [{:slots, 0}]

      expect_total_supply(hash_b_string, fn id -> {:ok, [%{id: id, result: @total_supply_hex}]} end)
      assert :ok = Fetcher.trigger_fetch(token_b)
      assert_receive {:rpc, ^hash_b_string}, 1_000
      assert_receive {:chain_event, :token_total_supply, :on_demand, [%Token{}]}, 1_000
    end

    test "does nothing when the fetcher is disabled" do
      initial = Application.get_env(:indexer, Fetcher.Supervisor) || []
      Application.put_env(:indexer, Fetcher.Supervisor, Keyword.merge(initial, disabled?: true))
      on_exit(fn -> Application.put_env(:indexer, Fetcher.Supervisor, initial) end)

      token = stale_token()

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      assert :ets.lookup(@table, key(token)) == []
      assert %{running: running} = :sys.get_state(Fetcher)
      assert running == %{}
    end

    test "does not raise when the fetcher is not running" do
      token = stale_token()
      stop_supervised!(Fetcher.Supervisor)

      assert :ets.whereis(@table) == :undefined
      assert :ok = Fetcher.trigger_fetch(token)
    end

    test "does not raise when ETS operations fail after the table check" do
      token = stale_token()
      # Simulates the table being torn down between `table_exists?/0` and the
      # ETS calls: the slot counter is gone, so `:ets.update_counter/3` raises.
      :ets.delete(@table, :slots)

      assert :ok = Fetcher.trigger_fetch(token)
      sync()

      assert %{running: running} = :sys.get_state(Fetcher)
      assert running == %{}
    end
  end

  describe "sweep" do
    test "removes expired failures and orphaned in-flight markers" do
      now = System.monotonic_time(:millisecond)
      threshold = :timer.minutes(5)

      :ets.insert(@table, {"expired_failed", :failed, now - threshold - 1})
      :ets.insert(@table, {"fresh_failed", :failed, now})
      :ets.insert(@table, {"orphaned_in_flight", :in_flight, now - 2 * threshold - 1})
      :ets.insert(@table, {"fresh_in_flight", :in_flight, now})

      send(Fetcher, :sweep)
      sync()

      assert :ets.lookup(@table, "expired_failed") == []
      assert :ets.lookup(@table, "orphaned_in_flight") == []
      assert [{"fresh_failed", :failed, _}] = :ets.lookup(@table, "fresh_failed")
      assert [{"fresh_in_flight", :in_flight, _}] = :ets.lookup(@table, "fresh_in_flight")
    end
  end

  defp stale_token, do: insert(:token, total_supply_updated_at_block: nil)

  defp key(%Token{contract_address_hash: %{bytes: bytes}}), do: bytes

  # Casts are processed in order, so a synchronous call afterwards guarantees
  # that all previously sent casts have been handled.
  defp sync, do: :sys.get_state(Fetcher)

  defp wait_until(fun, attempts \\ 50) do
    cond do
      fun.() ->
        :ok

      attempts == 0 ->
        flunk("condition was not met in time")

      true ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)
    end
  end

  defp expect_total_supply(hash_string, reply) do
    test_pid = self()

    expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_call", params: [params, "latest"]}], _opts ->
      assert params.data == @total_supply_selector
      assert params.to == hash_string
      send(test_pid, {:rpc, hash_string})
      reply.(id)
    end)
  end

  defp expect_blocking_total_supply(hash_string) do
    test_pid = self()

    expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_call", params: [params, "latest"]}], _opts ->
      assert params.to == hash_string
      send(test_pid, {:rpc, hash_string})
      send(test_pid, {:blocked, self()})

      receive do
        :continue -> {:ok, [%{id: id, result: @total_supply_hex}]}
      end
    end)
  end
end
