defmodule Explorer.Chain.Statistics.ServerTest do
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Chain.Statistics
  alias Explorer.Chain.Statistics.Server

  # shutdown: "owner exited with: shutdown" error from polluting logs when tests are successful
  @moduletag :capture_log

  describe "child_spec/1" do
    test "it defines a child_spec/1 that works with supervisors" do
      insert(:block)

      assert {:ok, pid} = start_supervised(Server)

      %Server{task: %Task{pid: pid}} = :sys.get_state(pid)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, _}
    end
  end

  describe "init/1" do
    test "returns a new chain when not told to refresh" do
      empty_statistics = %Statistics{}

      assert {:ok, %Server{statistics: ^empty_statistics}} = Server.init(refresh: false)
    end

    test "returns a new Statistics when told to refresh" do
      empty_statistics = %Statistics{}

      assert {:ok, %Server{statistics: ^empty_statistics}} = Server.init(refresh: true)
    end

    test "refreshes when told to refresh" do
      {:ok, _} = Server.init([])

      assert_receive :refresh, 2_000
    end
  end

  describe "handle_info/2" do
    setup :state

    test "returns the original statistics when sent a :refresh message", %{
      state: %Server{statistics: statistics} = state
    } do
      assert {:noreply, %Server{statistics: ^statistics, task: task}} = Server.handle_info(:refresh, state)

      Task.await(task)
    end

    test "launches a Statistics.fetch Task update when sent a :refresh message", %{state: state} do
      assert {:noreply, %Server{task: %Task{} = task}} = Server.handle_info(:refresh, state)

      assert %Statistics{} = Task.await(task)
    end

    test "stores successful Task in state", %{state: state} do
      # so that `statistics` from Task will be different
      insert(:block)

      assert {:noreply, %Server{task: %Task{ref: ref}} = refresh_state} = Server.handle_info(:refresh, state)

      assert_receive {^ref, %Statistics{} = message_statistics} = message

      assert {:noreply, %Server{statistics: ^message_statistics, task: nil}} =
               Server.handle_info(message, refresh_state)

      refute message_statistics == state.statistics
    end

    test "logs crashed Task", %{state: state} do
      assert {:noreply, %Server{task: %Task{pid: pid, ref: ref}} = refresh_state} = Server.handle_info(:refresh, state)

      Process.exit(pid, :boom)

      assert_receive {:DOWN, ^ref, :process, ^pid, :boom} = message

      captured_log =
        capture_log(fn ->
          assert {:noreply, %Server{task: nil}} = Server.handle_info(message, refresh_state)
        end)

      assert captured_log =~ "Explorer.Chain.Statistics.fetch failed and could not be cached: :boom"
    end
  end

  describe "handle_call/3" do
    test "replies with statistics when sent a :fetch message" do
      original = Statistics.fetch()
      state = %Server{statistics: original}

      assert {:reply, ^original, ^state} = Server.handle_call(:fetch, self(), state)
    end
  end

  describe "terminate/2" do
    setup :state

    test "cleans up in-progress tasks when terminated", %{state: state} do
      assert {:noreply, %Server{task: %Task{pid: pid}} = refresh_state} = Server.handle_info(:refresh, state)

      second_ref = Process.monitor(pid)

      Server.terminate(:boom, refresh_state)

      assert_receive {:DOWN, ^second_ref, :process, ^pid, :shutdown}
    end
  end

  defp state(_) do
    {:ok, state} = Server.init([])

    %{state: state}
  end
end
