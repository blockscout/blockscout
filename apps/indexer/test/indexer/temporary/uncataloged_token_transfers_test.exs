defmodule Indexer.Temporary.UncatalogedTokenTransfersTest do
  use Explorer.DataCase

  alias Indexer.Block.Catchup.Sequence
  alias Indexer.Temporary.UncatalogedTokenTransfers

  @moduletag :capture_log

  describe "start_link/1" do
    test "starts the worker" do
      assert {:ok, _pid} = UncatalogedTokenTransfers.start_link(supervisor: self())
    end
  end

  describe "init/1" do
    test "sends message to self" do
      pid = self()

      assert {:ok, %{task_ref: nil, block_numbers: [], sup_pid: ^pid}} =
               UncatalogedTokenTransfers.init(supervisor: self())

      assert_received :scan
    end
  end

  describe "handle_info with :scan" do
    test "sends shutdown to supervisor" do
      state = %{task_ref: nil, block_numbers: [], sup_pid: self()}
      Task.async(fn -> UncatalogedTokenTransfers.handle_info(:scan, state) end)
      assert_receive {_, _, {:terminate, :normal}}, 200
    end

    test "sends message to self when uncataloged token transfers are found" do
      block = insert(:block)
      address = insert(:address)

      transaction =
        insert(:transaction,
          block_number: block.number,
          block_hash: block.hash,
          cumulative_gas_used: 0,
          gas_used: 0,
          index: 0
        )

      log =
        insert(:token_transfer_log,
          transaction: transaction,
          address_hash: address.hash,
          block: block
        )

      block_number = log.block_number

      expected_state = %{task_ref: nil, block_numbers: [block_number], retry_interval: 1}
      state = %{task_ref: nil, block_numbers: [], retry_interval: 1}

      assert {:noreply, ^expected_state} = UncatalogedTokenTransfers.handle_info(:scan, state)
      assert_receive :push_front_blocks
    end
  end

  describe "handle_info with :push_front_blocks" do
    test "starts a task" do
      task_sup_pid = start_supervised!({Task.Supervisor, name: UncatalogedTokenTransfers.TaskSupervisor})
      start_supervised!({Sequence, [[ranges: [], step: -1], [name: :block_catchup_sequencer]]})

      state = %{task_ref: nil, block_numbers: [1]}
      assert {:noreply, %{task_ref: task_ref}} = UncatalogedTokenTransfers.handle_info(:push_front_blocks, state)
      assert is_reference(task_ref)

      refute_receive {^task_ref, {:error, :queue_unavailable}}
      assert_receive {^task_ref, :ok}

      stop_supervised(task_sup_pid)
    end
  end

  describe "handle_info with task ref tuple" do
    test "sends shutdown to supervisor on success" do
      ref = Process.monitor(self())
      state = %{task_ref: ref, block_numbers: [], sup_pid: self()}
      Task.async(fn -> assert UncatalogedTokenTransfers.handle_info({ref, :ok}, state) end)
      assert_receive {_, _, {:terminate, :normal}}
    end

    test "sends message to self to try again on failure" do
      ref = Process.monitor(self())
      state = %{task_ref: ref, block_numbers: [1], sup_pid: self(), retry_interval: 1}
      expected_state = %{state | task_ref: nil}

      assert {:noreply, ^expected_state} =
               UncatalogedTokenTransfers.handle_info({ref, {:error, :queue_unavailable}}, state)

      assert_receive :push_front_blocks
    end
  end

  describe "handle_info with failed task" do
    test "sends message to self to try again" do
      ref = Process.monitor(self())
      state = %{task_ref: ref, block_numbers: [1], sup_pid: self(), retry_interval: 1}

      assert {:noreply, %{task_ref: nil}} =
               UncatalogedTokenTransfers.handle_info({:DOWN, ref, :process, self(), :EXIT}, state)

      assert_receive :push_front_blocks
    end
  end
end
