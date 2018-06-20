defmodule Explorer.Indexer.SequenceTest do
  use ExUnit.Case

  alias Explorer.Indexer.Sequence

  test "start_link" do
    {:ok, pid} = Sequence.start_link([1..4], 5, 1)

    assert state(pid) == %Sequence{
             current: 5,
             mode: :infinite,
             queue: {[1..4], []},
             step: 1
           }
  end

  test "inject_range" do
    {:ok, pid} = Sequence.start_link([1..2], 5, 1)

    assert :ok = Sequence.inject_range(pid, 3..4)

    assert state(pid) == %Sequence{
             current: 5,
             mode: :infinite,
             queue: {[3..4], [1..2]},
             step: 1
           }
  end

  test "cap" do
    {:ok, pid} = Sequence.start_link([1..2], 5, 1)

    assert :ok = Sequence.cap(pid)
    assert state(pid).mode == :finite
  end

  describe "pop" do
    test "with a non-empty queue in finite and infinite modes" do
      {:ok, pid} = Sequence.start_link([1..4, 6..9], 99, 5)

      assert 1..4 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 99,
               mode: :infinite,
               queue: {[], [6..9]},
               step: 5
             }

      :ok = Sequence.cap(pid)

      assert 6..9 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 99,
               mode: :finite,
               queue: {[], []},
               step: 5
             }
    end

    test "with an empty queue in infinite mode" do
      {:ok, pid} = Sequence.start_link([], 5, 5)

      assert 5..9 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 10,
               mode: :infinite,
               queue: {[], []},
               step: 5
             }
    end

    test "with an empty queue in infinit mode with negative step" do
      {:ok, pid} = Sequence.start_link([], 4, -5)

      assert 4..0 == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 0,
               mode: :finite,
               queue: {[], []},
               step: -5
             }
    end

    test "with an empty queue in finite mode" do
      {:ok, pid} = Sequence.start_link([], 5, 5)
      :ok = Sequence.cap(pid)

      assert :halt == Sequence.pop(pid)

      assert state(pid) == %Sequence{
               current: 5,
               mode: :finite,
               queue: {[], []},
               step: 5
             }
    end
  end

  defp state(sequencer) do
    Agent.get(sequencer, & &1)
  end
end
