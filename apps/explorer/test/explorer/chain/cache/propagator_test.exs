# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.PropagatorTest do
  # `Explorer.mode/0` is global state
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Explorer.Chain.Cache.{Blocks, Propagator, Transactions}

  defmodule TestMapCache do
    use Explorer.Chain.MapCache,
      name: :propagator_test_map_cache,
      keys: [:foo, :bar, :async_task]

    # both return shapes are used so that the type checker does not flag the
    # `{:update, _}` branch of `get/1` as unreachable
    def handle_fallback(:bar), do: {:update, 0}
    def handle_fallback(_key), do: {:return, nil}
  end

  @nodes [:api1@test, :api2@test]

  defp start_propagator(opts) do
    test_pid = self()

    default_opts = [
      name: nil,
      flush_interval: 10,
      send_timeout: 5_000,
      nodes_fun: fn -> @nodes end,
      multicast_fun: fn nodes, module, function, args ->
        send(test_pid, {:multicast, self(), nodes, module, function, args})
        :ok
      end
    ]

    start_supervised!({Propagator, Keyword.merge(default_opts, opts)})
  end

  describe "enqueue_ordered/3" do
    test "coalesces pending elements: newest version of an id wins, ordered by prevails?/2, capped to max_size/0" do
      pid = start_propagator(flush_interval: :timer.minutes(1))

      Propagator.enqueue_ordered(Blocks, [{1, :one}, {3, :three}], pid)
      Propagator.enqueue_ordered(Blocks, [{2, :two}, {3, :three_v2}], pid)

      assert Propagator.pending(pid) == %{{:ordered, Blocks} => [{3, :three_v2}, {2, :two}, {1, :one}]}

      max_size = Blocks.max_size()
      Propagator.enqueue_ordered(Blocks, Enum.map(1..(max_size + 10), &{&1, &1}), pid)

      %{{:ordered, Blocks} => pending} = Propagator.pending(pid)
      assert length(pending) == max_size
      assert hd(pending) == {max_size + 10, max_size + 10}
    end

    test "sends the pending elements to the other nodes with propagate: false" do
      pid = start_propagator([])

      Propagator.enqueue_ordered(Transactions, [{{1, 0}, :transaction}], pid)

      assert_receive {:multicast, _sender, @nodes, Transactions, :do_raw_update, [[{{1, 0}, :transaction}], false]}
      assert Propagator.pending(pid) == %{}
    end
  end

  describe "enqueue_map/3" do
    setup do
      start_supervised!(TestMapCache)
      :ok
    end

    test "deduplicates keys and sends their current local values" do
      pid = start_propagator([])
      TestMapCache.set(:foo, 1)

      Propagator.enqueue_map(TestMapCache, [:foo, :foo, :bar], pid)

      assert_receive {:multicast, _sender, @nodes, TestMapCache, :apply_propagated, [%{foo: 1, bar: nil}]}
    end

    test "apply_propagated/1 stores the received values" do
      TestMapCache.apply_propagated(%{foo: 7, bar: 8})

      assert TestMapCache.get_all() == %{foo: 7, bar: 8, async_task: nil}
    end

    test "set/2 and update/2 mark the key dirty on indexer nodes, except for :async_task" do
      old_mode = Application.get_env(:explorer, :mode)
      Application.put_env(:explorer, :mode, :indexer)
      on_exit(fn -> Application.put_env(:explorer, :mode, old_mode) end)

      TestMapCache.set(:foo, 1)
      TestMapCache.update(:bar, 2)
      TestMapCache.set_async_task(self())

      assert TestMapCache.get_all() == %{foo: 1, bar: 2, async_task: self()}
      assert Propagator.pending()[{:map, TestMapCache}] == MapSet.new([:foo, :bar])
    end
  end

  describe "in-flight batches" do
    test "at most one batch is in flight, data queued meanwhile is coalesced and sent afterwards" do
      test_pid = self()

      blocking_multicast = fn nodes, module, function, args ->
        send(test_pid, {:multicast, self(), nodes, module, function, args})

        receive do
          :continue -> :ok
        end
      end

      pid = start_propagator(multicast_fun: blocking_multicast)

      Propagator.enqueue_ordered(Blocks, [{1, :one}], pid)
      assert_receive {:multicast, sender, @nodes, Blocks, :do_raw_update, [[{1, :one}], false]}

      Propagator.enqueue_ordered(Blocks, [{2, :two}], pid)
      Propagator.enqueue_ordered(Blocks, [{3, :three}], pid)
      Propagator.flush(pid)

      refute_receive {:multicast, _, _, Blocks, _, _}, 50
      assert Propagator.pending(pid) == %{{:ordered, Blocks} => [{3, :three}, {2, :two}]}

      send(sender, :continue)

      assert_receive {:multicast, sender, @nodes, Blocks, :do_raw_update, [[{3, :three}, {2, :two}], false]}
      send(sender, :continue)
    end

    test "kills a sender exceeding send_timeout, drops its batch and keeps working" do
      test_pid = self()

      stuck_multicast = fn nodes, module, function, args ->
        send(test_pid, {:multicast, self(), nodes, module, function, args})
        Process.sleep(:infinity)
      end

      pid = start_propagator(multicast_fun: stuck_multicast, send_timeout: 50)

      log =
        capture_log(fn ->
          Propagator.enqueue_ordered(Blocks, [{1, :one}], pid)

          assert_receive {:multicast, sender, @nodes, Blocks, _, _}
          ref = Process.monitor(sender)
          assert_receive {:DOWN, ^ref, :process, ^sender, :killed}, 1_000

          Propagator.enqueue_ordered(Blocks, [{2, :two}], pid)
          assert_receive {:multicast, _, @nodes, Blocks, :do_raw_update, [[{2, :two}], false]}
        end)

      assert log =~ "did not complete"
    end

    test "drops the pending data when there are no other nodes" do
      pid = start_propagator(nodes_fun: fn -> [] end)

      Propagator.enqueue_ordered(Blocks, [{1, :one}], pid)
      Propagator.flush(pid)

      assert Propagator.pending(pid) == %{}
      refute_receive {:multicast, _, _, _, _, _}, 50
    end
  end
end
