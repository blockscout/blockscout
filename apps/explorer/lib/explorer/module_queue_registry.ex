defmodule Explorer.ModuleQueueRegistry do
  @moduledoc """
  Generic registry for module-scoped ETS-backed queues.
  """

  alias Explorer.BoundQueue

  @doc """
  Returns the ETS table name for the queue belonging to the given module.
  """
  @callback table_name(module()) :: atom()

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Explorer.ModuleQueueRegistry

      alias Explorer.ModuleQueueRegistry

      @spec pop(module()) :: term() | nil
      def pop(module), do: ModuleQueueRegistry.pop(__MODULE__, module)

      @spec push(term(), module()) :: true
      def push(value, module), do: ModuleQueueRegistry.push(__MODULE__, value, module)
    end
  end

  @doc """
  Pops a value from the front of the queue for the specified module.
  """
  @spec pop(module(), module()) :: term() | nil
  def pop(registry_module, module) do
    table_name = registry_module.table_name(module)

    :global.trans({__MODULE__, table_name}, fn ->
      case BoundQueue.pop_front(queue_get(table_name)) do
        {:ok, {value, updated_queue}} ->
          :ets.insert(table_name, {:queue, updated_queue})
          value

        {:error, :empty} ->
          nil
      end
    end)
  end

  @doc """
  Pushes a value to the back of the queue for the specified module.
  """
  @spec push(module(), term(), module()) :: true
  def push(registry_module, value, module) do
    table_name = registry_module.table_name(module)

    :global.trans({__MODULE__, table_name}, fn ->
      {:ok, updated_queue} = BoundQueue.push_back(queue_get(table_name), value)

      :ets.insert(table_name, {:queue, updated_queue})
    end)
  end

  @spec queue_get(atom()) :: BoundQueue.t(term())
  defp queue_get(table_name) do
    ensure_table(table_name)

    case :ets.lookup(table_name, :queue) do
      [{:queue, value}] -> value
      [] -> %BoundQueue{}
    end
  end

  defp ensure_table(table_name) do
    if :ets.whereis(table_name) == :undefined do
      try do
        :ets.new(table_name, [
          :set,
          :named_table,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])
      rescue
        ArgumentError -> :ok
      end
    end
  end
end
