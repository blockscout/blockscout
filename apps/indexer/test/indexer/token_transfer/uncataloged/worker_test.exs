defmodule Indexer.TokenTransfer.Uncataloged.WorkerTest do
  use Explorer.DataCase

  alias Indexer.TokenTransfer.Uncataloged.{Worker, TaskSupervisor}

  describe "start_link/1" do
    test "starts the worker" do
      assert {:ok, _pid} = Worker.start_link([supervisor: self()])
    end
  end

  describe "init/1" do
    test "sends message to self" do
      pid = self()
      assert {:ok, %{task_ref: nil, block_numbers: [], sup_pid: ^pid}} = Worker.init(supervisor: self())
      assert_received :scan
    end
  end

  describe "handle_info with :scan" do
    test "sends shutdown to supervisor" do
      state = %{task_ref: nil, block_numbers: [], sup_pid: self()}
      Task.async(fn -> Worker.handle_info(:scan, state) end)
      assert_receive {_, _, {:terminate, :normal}}
    end

    test "sends message to self when uncataloged token transfers are found" do
      log = insert(:token_transfer_log)
      block_number = log.transaction.block_number

      expected_state = %{task_ref: nil, block_numbers: [block_number], retry_interval: 1}
      state = %{task_ref: nil, block_numbers: [], retry_interval: 1}

      assert {:noreply, ^expected_state} = Worker.handle_info(:scan, state)
      assert_receive :enqueue_blocks
    end
  end

  describe "handle_info with :enqueue_blocks" do
    test "starts a task" do
      task_sup_pid = start_supervised!({Task.Supervisor, name: TaskSupervisor})

      state = %{task_ref: nil, block_numbers: [1]}
      assert {:noreply, new_state} = Worker.handle_info(:enqueue_blocks, state)
      assert is_reference(new_state.task_ref)

      stop_supervised(task_sup_pid)
    end
  end

  describe "handle_info with task ref tuple" do
    test "sends shutdown to supervisor on success" do
      ref = Process.monitor(self())
      state = %{task_ref: ref, block_numbers: [], sup_pid: self()}
      Task.async(fn -> assert Worker.handle_info({ref, :ok}, state) end)
      assert_receive {_, _, {:terminate, :normal}}
    end
  end

  describe "handle_info with failed task" do
    test "sends message to self to try again" do
      ref = Process.monitor(self())
      state = %{task_ref: ref, block_numbers: [1], sup_pid: self(), retry_interval: 1}
      assert {:noreply, %{task_ref: nil}} = Worker.handle_info({:DOWN, ref, :process, self(), :EXIT}, state)
      assert_receive :enqueue_blocks
    end
  end
end
