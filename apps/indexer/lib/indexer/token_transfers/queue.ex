defmodule Explorer.Indexer.TokenTransfers.Queue do
  @doc false

  @type queue :: {[term()], [term()]}

  @spec new :: queue()
  def new do
    :queue.new()
  end

  @spec enqueue_list(queue(), [term()]) :: queue()
  def enqueue_list(queue, list) when is_list(list) do
    Enum.reduce(list, queue, fn item, acc -> enqueue(acc, item) end)
  end

  @spec enqueue(queue(), term()) :: queue()
  def enqueue(queue, item) do
    :queue.in_r(item, queue)
  end

  @spec dequeue(queue()) :: {:ok, {queue(), term()}} | {:error, :empty}
  def dequeue(queue) do
    case :queue.out(queue) do
      {{:value, item}, next_queue} ->
        {:ok, {next_queue, item}}

      {:empty, _queue} ->
        {:error, :empty}
    end
  end
end
