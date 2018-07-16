defmodule Indexer.SequenceTest do
  use ExUnit.Case

  alias Indexer.Sequence

  describe "start_link/1" do
    test "sets state" do
      {:ok, pid} = Sequence.start_link(prefix: [1..4], first: 5, step: 1)

      assert Sequence.pop(pid) == 1..1
      assert Sequence.pop(pid) == 2..2
      assert Sequence.pop(pid) == 3..3
      assert Sequence.pop(pid) == 4..4
      # infinite sequence takes over
      assert Sequence.pop(pid) == 5..5
    end

    # Regression test for https://github.com/poanetwork/poa-explorer/issues/387
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

  test "inject_range" do
    {:ok, pid} = Sequence.start_link(prefix: [1..2], first: 5, step: 1)

    assert :ok = Sequence.inject_range(pid, 3..4)

    assert Sequence.pop(pid) == 1..1
    assert Sequence.pop(pid) == 2..2
    assert Sequence.pop(pid) == 3..3
    assert Sequence.pop(pid) == 4..4
    # infinite sequence takes over
    assert Sequence.pop(pid) == 5..5
  end

  describe "cap/1" do
    test "returns previous mode" do
      {:ok, pid} = Sequence.start_link(prefix: [1..2], first: 5, step: 1)

      assert Sequence.cap(pid) == :infinite
      assert Sequence.cap(pid) == :finite
    end

    test "disables infinite mode that uses first and step" do
      {:ok, late_capped} = Sequence.start_link(prefix: [1..2], first: 5, step: 1)

      assert Sequence.pop(late_capped) == 1..1
      assert Sequence.pop(late_capped) == 2..2
      assert Sequence.pop(late_capped) == 5..5
      assert Sequence.cap(late_capped) == :infinite
      assert Sequence.pop(late_capped) == :halt

      {:ok, immediately_capped} = Sequence.start_link(prefix: [1..2], first: 5, step: 1)

      assert Sequence.cap(immediately_capped) == :infinite
      assert Sequence.pop(immediately_capped) == 1..1
      assert Sequence.pop(immediately_capped) == 2..2
      assert Sequence.pop(immediately_capped) == :halt
    end
  end

  describe "pop" do
    test "with a non-empty queue in finite and infinite modes" do
      {:ok, pid} = Sequence.start_link(prefix: [1..4, 6..9], first: 99, step: 5)

      assert 1..4 == Sequence.pop(pid)

      assert :infinite = Sequence.cap(pid)

      assert 6..9 == Sequence.pop(pid)
    end

    test "with an empty queue in infinite mode returns range from next step from current" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)

      assert 5..9 == Sequence.pop(pid)
    end

    test "with an empty queue in infinite mode with negative step does not go past 0" do
      {:ok, pid} = Sequence.start_link(first: 4, step: -5)

      assert Sequence.pop(pid) == 4..0
      assert Sequence.pop(pid) == :halt
    end

    test "with an empty queue in finite mode halts immediately" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)
      :infinite = Sequence.cap(pid)

      assert Sequence.pop(pid) == :halt
    end
  end
end
