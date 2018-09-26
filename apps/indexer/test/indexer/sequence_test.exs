defmodule Indexer.SequenceTest do
  use ExUnit.Case

  alias Indexer.Sequence

  describe "start_link/1" do
    test "without :ranges with :first with positive step pops infinitely" do
      {:ok, ascending} = Sequence.start_link(first: 5, step: 1)

      assert Sequence.pop(ascending) == 5..5
      assert Sequence.pop(ascending) == 6..6
    end

    test "without :ranges with :first with negative :step is error" do
      {child_pid, child_ref} =
        spawn_monitor(fn ->
          Sequence.start_link(first: 1, step: -1)
          Process.sleep(5_000)
        end)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid,
                      ":step must be a positive integer for infinite sequences"}
    end

    test "without :ranges without :first returns error" do
      {child_pid, child_ref} =
        spawn_monitor(fn ->
          Sequence.start_link(step: -1)
          Process.sleep(5_000)
        end)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid, "either :ranges or :first must be set"}
    end

    test "with ranges without :first" do
      {:ok, pid} = Sequence.start_link(ranges: [1..4], step: 1)

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 2..2
      assert Sequence.pop(pid) == 3..3
      assert Sequence.pop(pid) == 4..4
      assert Sequence.pop(pid) == :halt
    end

    test "with :ranges with :first returns error" do
      {child_pid, child_ref} =
        spawn_monitor(fn ->
          Sequence.start_link(ranges: [1..0], first: 1, step: -1)
          Process.sleep(5_000)
        end)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid,
                      ":ranges and :first cannot be set at the same time" <>
                        " as :ranges is for :finite mode while :first is for :infinite mode"}
    end

    test "with 0 first with negative step does not return 0 twice" do
      {:ok, pid} = Sequence.start_link(ranges: [1..0], step: -1)

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 0..0
      assert Sequence.pop(pid) == :halt
    end

    # Regression test for https://github.com/poanetwork/blockscout/issues/387
    test "ensures Sequence shuts down when parent process dies" do
      parent = self()

      {child_pid, child_ref} = spawn_monitor(fn -> send(parent, Sequence.start_link(first: 1, step: 1)) end)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid, :normal}
      assert_receive {:ok, sequence_pid} when is_pid(sequence_pid)

      sequence_ref = Process.monitor(sequence_pid)

      # noproc when the sequence has already died by the time monitor is called
      assert_receive {:DOWN, ^sequence_ref, :process, ^sequence_pid, status} when status in [:normal, :noproc]
    end
  end

  describe "queue/2" do
    test "with finite mode range is chunked" do
      {:ok, pid} = Sequence.start_link(ranges: [1..0], step: -1)

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 0..0

      assert Sequence.queue(pid, 1..0) == :ok

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 0..0
      assert Sequence.pop(pid) == :halt
      assert Sequence.pop(pid) == :halt
    end

    test "with finite mode with range in wrong direction returns error" do
      {:ok, ascending} = Sequence.start_link(first: 0, step: 1)

      assert Sequence.queue(ascending, 1..0) == {:error, "Range (1..0) direction is opposite step (1) direction"}

      {:ok, descending} = Sequence.start_link(ranges: [1..0], step: -1)

      assert Sequence.queue(descending, 0..1) == {:error, "Range (0..1) direction is opposite step (-1) direction"}
    end

    test "with infinite mode range is chunked and is returned prior to calculated ranges" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 1)

      assert :ok = Sequence.queue(pid, 3..4)

      assert Sequence.pop(pid) == 3..3
      assert Sequence.pop(pid) == 4..4
      # infinite sequence takes over
      assert Sequence.pop(pid) == 5..5
      assert Sequence.pop(pid) == 6..6
    end
  end

  describe "queue_front/2" do
    test "with finite mode range is chunked" do
      {:ok, pid} = Sequence.start_link(ranges: [1..0], step: -1)

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 0..0

      assert Sequence.queue_front(pid, 1..0) == :ok

      assert Sequence.pop(pid) == 0..0
      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == :halt
      assert Sequence.pop(pid) == :halt
    end

    test "with finite mode with range in wrong direction returns error" do
      {:ok, ascending} = Sequence.start_link(first: 0, step: 1)

      assert Sequence.queue_front(ascending, 1..0) == {:error, "Range (1..0) direction is opposite step (1) direction"}

      {:ok, descending} = Sequence.start_link(ranges: [1..0], step: -1)

      assert Sequence.queue_front(descending, 0..1) ==
               {:error, "Range (0..1) direction is opposite step (-1) direction"}
    end

    test "with infinite mode range is chunked and is returned prior to calculated ranges" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 1)

      assert :ok = Sequence.queue_front(pid, 3..4)

      assert Sequence.pop(pid) == 4..4
      assert Sequence.pop(pid) == 3..3
      # infinite sequence takes over
      assert Sequence.pop(pid) == 5..5
      assert Sequence.pop(pid) == 6..6
    end
  end

  describe "cap/1" do
    test "returns previous mode" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 1)

      assert Sequence.cap(pid) == :infinite
      assert Sequence.cap(pid) == :finite
    end

    test "disables infinite mode that uses first and step" do
      {:ok, late_capped} = Sequence.start_link(first: 5, step: 1)

      assert Sequence.pop(late_capped) == 5..5
      assert Sequence.pop(late_capped) == 6..6
      assert Sequence.queue(late_capped, 5..5) == :ok
      assert Sequence.cap(late_capped) == :infinite
      assert Sequence.pop(late_capped) == 5..5
      assert Sequence.pop(late_capped) == :halt

      {:ok, immediately_capped} = Sequence.start_link(first: 5, step: 1)

      assert Sequence.cap(immediately_capped) == :infinite
      assert Sequence.pop(immediately_capped) == :halt
    end
  end

  describe "pop" do
    test "with a non-empty queue in finite mode" do
      {:ok, pid} = Sequence.start_link(ranges: [1..4, 6..9], step: 5)

      assert Sequence.pop(pid) == 1..4
      assert Sequence.pop(pid) == 6..9
      assert Sequence.pop(pid) == :halt
      assert Sequence.pop(pid) == :halt
    end

    test "with an empty queue in infinite mode returns range from next step from current" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)

      assert 5..9 == Sequence.pop(pid)
    end

    test "with an empty queue in finite mode halts immediately" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)
      :infinite = Sequence.cap(pid)

      assert Sequence.pop(pid) == :halt
    end
  end
end
