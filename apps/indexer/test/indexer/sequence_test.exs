defmodule Indexer.SequenceTest do
  use ExUnit.Case

  alias Indexer.Sequence

  describe "start_link/1" do
    test "sets state" do
      {:ok, pid} = Sequence.start_link(prefix: [1..4], first: 5, step: 1)

      assert state(pid) == %Sequence{
               current: 5,
               mode: :infinite,
               queue: {[1..4], []},
               step: 1
             }
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

    assert state(pid) == %Sequence{
             current: 5,
             mode: :infinite,
             queue: {[3..4], [1..2]},
             step: 1
           }
  end

  test "cap" do
    {:ok, pid} = Sequence.start_link(prefix: [1..2], first: 5, step: 1)

    assert :infinite = Sequence.cap(pid)
    assert state(pid).mode == :finite
    assert :finite = Sequence.cap(pid)
  end

  describe "pop" do
    test "with a non-empty queue in finite and infinite modes" do
      {:ok, pid} = Sequence.start_link(prefix: [1..4, 6..9], first: 99, step: 5)

      assert 1..4 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 99,
               mode: :infinite,
               queue: {[], [6..9]},
               step: 5
             }

      :infinite = Sequence.cap(pid)

      assert 6..9 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 99,
               mode: :finite,
               queue: {[], []},
               step: 5
             }
    end

    test "with an empty queue in infinite mode" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)

      assert 5..9 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 10,
               mode: :infinite,
               queue: {[], []},
               step: 5
             }
    end

    test "with an empty queue in infinit mode with negative step" do
      {:ok, pid} = Sequence.start_link(first: 4, step: -5)

      assert 4..0 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 0,
               mode: :finite,
               queue: {[], []},
               step: -5
             }
    end

    test "with an empty queue in finite mode" do
      {:ok, pid} = Sequence.start_link(first: 5, step: 5)
      :infinite = Sequence.cap(pid)

      assert :halt == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 5,
               mode: :finite,
               queue: {[], []},
               step: 5
             }
    end
  end

  defp state(sequence) do
    :sys.get_state(sequence)
  end
end
