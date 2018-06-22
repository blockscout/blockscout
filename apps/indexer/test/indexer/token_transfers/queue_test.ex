defmodule Indexer.TokenTransfers.QueueTest do
  use ExUnit.Case

  alias Indexer.TokenTransfers.Queue

  test "new/0" do
    assert Queue.new() == {[], []}
  end

  test "enqueue_list/2" do
    assert Queue.enqueue_list(Queue.new(), [1, 2, 3, 4]) == {[1], [4, 3, 2]}
  end

  test "enqueue/2" do
    assert Queue.enqueue(Queue.new(), 1) == {[], [1]}
  end

  describe "dequeue/1" do
    test "with empty queue" do
      assert {:error, :empty} == Queue.dequeue(Queue.new())
    end

    test "with non-empty queue" do
      queue = Queue.enqueue_list(Queue.new(), [1, 2])
      assert {:ok, {{[], [1]}, 2}} == Queue.dequeue(queue)
    end
  end
end
