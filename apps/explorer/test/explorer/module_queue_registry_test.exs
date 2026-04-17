defmodule Explorer.ModuleQueueRegistryTest do
  use ExUnit.Case, async: false

  alias Explorer.BoundQueue
  alias Explorer.ModuleQueueRegistry

  defmodule Registry do
    use ModuleQueueRegistry

    @impl true
    def table_name(module) do
      :"#{module}_module_queue_registry_test"
    end
  end

  defmodule ModuleA do
  end

  defmodule ModuleB do
  end

  setup do
    for table_name <- [Registry.table_name(ModuleA), Registry.table_name(ModuleB)] do
      if :ets.whereis(table_name) != :undefined do
        :ets.delete(table_name)
      end
    end

    :ok
  end

  test "pop/1 returns nil for an empty queue" do
    assert Registry.pop(ModuleA) == nil
  end

  test "push/2 returns true and pop/1 returns values in FIFO order" do
    assert Registry.push(1, ModuleA) == true
    assert Registry.push(2, ModuleA) == true

    assert Registry.pop(ModuleA) == 1
    assert Registry.pop(ModuleA) == 2
    assert Registry.pop(ModuleA) == nil
  end

  test "queues are isolated by module table name" do
    assert Registry.push(:a, ModuleA) == true
    assert Registry.push(:b, ModuleB) == true

    assert Registry.pop(ModuleA) == :a
    assert Registry.pop(ModuleB) == :b
  end

  test "push/2 returns {:error, :maximum_size} when queue is full" do
    table_name = Registry.table_name(ModuleA)

    :ets.new(table_name, [:set, :named_table, :public])
    :ets.insert(table_name, {:queue, %BoundQueue{queue: :queue.from_list([:existing]), size: 1, maximum_size: 1}})

    assert Registry.push(:overflow, ModuleA) == {:error, :maximum_size}
    assert Registry.pop(ModuleA) == :existing
    assert Registry.pop(ModuleA) == nil
  end
end
