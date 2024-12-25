defmodule Explorer.BoundQueue do
  @moduledoc """
  A queue that tracks its size and can have its size bound to a maximum.
  """

  defstruct queue: :queue.new(),
            size: 0,
            maximum_size: nil

  @typedoc """
   * `queue` - underlying Erlang `:queue`.
   * `size` - the size of `queue`.
   * `max_size` - the maximum `size.  May be `nil` when there is no bound on the `queue`.
  """
  @type t(item) :: %__MODULE__{
          queue: :queue.queue(item),
          size: non_neg_integer(),
          maximum_size: non_neg_integer() | nil
        }

  @doc """
  Removes the first element from the back of the queue.

  Returns the updated queue.
  """

  @spec drop_back(%__MODULE__{size: 0}) :: {:error, :empty}
  def drop_back(%__MODULE__{size: 0}), do: {:error, :empty}

  @spec drop_back(%__MODULE__{size: pos_integer()}) :: {:ok, t(item)} when item: term()
  def drop_back(%__MODULE__{queue: queue, size: size} = bound_queue) do
    updated_queue = :queue.drop_r(queue)
    {:ok, %__MODULE__{bound_queue | queue: updated_queue, size: size - 1}}
  end

  @doc """
  Removes the first element from the front of the queue.

  Returns the first element and the updated queue.
  """

  @spec pop_front(%__MODULE__{size: 0}) :: {:error, :empty}
  def pop_front(%__MODULE__{size: 0}), do: {:error, :empty}

  @spec pop_front(%__MODULE__{size: pos_integer()}) :: {:ok, {item, t(item)}} when item: term()
  def pop_front(%__MODULE__{queue: queue, size: size} = bound_queue) do
    {{:value, item}, updated_queue} = :queue.out(queue)
    {:ok, {item, %__MODULE__{bound_queue | queue: updated_queue, size: size - 1}}}
  end

  @doc """
  Removes the last element from the back of queue.

  Returns the last element and the updated queue.
  """

  @spec pop_back(%__MODULE__{size: 0}) :: {:error, :empty}
  def pop_back(%__MODULE__{size: 0}), do: {:error, :empty}

  @spec pop_back(%__MODULE__{size: pos_integer()}) :: {:ok, {item, t(item)}} when item: term()
  def pop_back(%__MODULE__{queue: queue, size: size} = bound_queue) do
    {{:value, item}, updated_queue} = :queue.out_r(queue)
    {:ok, {item, %__MODULE__{bound_queue | queue: updated_queue, size: size - 1}}}
  end

  @doc """
  Adds `element` as the first element at the front of the queue.
  """
  @spec push_front(t(item), item) :: {:ok, t(item)} | {:error, :maximum_size} when item: term()
  def push_front(%__MODULE__{size: maximum_size, maximum_size: maximum_size}, _), do: {:error, :maximum_size}

  def push_front(%__MODULE__{queue: queue, size: size} = bound_queue, item) do
    updated_queue = :queue.in_r(item, queue)
    {:ok, %__MODULE__{bound_queue | queue: updated_queue, size: size + 1}}
  end

  @doc """
  Adds `element` as last element at the back of the queue.
  """
  @spec push_back(t(item), item) :: {:ok, t(item)} | {:error, :maximum_size} when item: term()
  def push_back(%__MODULE__{size: maximum_size, maximum_size: maximum_size}, _), do: {:error, :maximum_size}

  def push_back(%__MODULE__{queue: queue, size: size} = bound_queue, item) do
    updated_queue = :queue.in(item, queue)
    {:ok, %__MODULE__{bound_queue | queue: updated_queue, size: size + 1}}
  end

  @doc """
  `push_back/2` items from `items` into `bound_queue` until it is full.
  """
  def push_back_until_maximum_size(
        %__MODULE__{size: maximum_size, maximum_size: maximum_size} = bound_queue,
        remaining
      ),
      do: {bound_queue, remaining}

  def push_back_until_maximum_size(%__MODULE__{} = bound_queue, [] = remaining), do: {bound_queue, remaining}

  def push_back_until_maximum_size(%__MODULE__{} = bound_queue, [head | tail] = remaining) do
    case push_back(bound_queue, head) do
      {:ok, new_bound_queue} -> push_back_until_maximum_size(new_bound_queue, tail)
      {:error, :maximum_size} -> {bound_queue, remaining}
    end
  end

  @doc """
  `push_front/2` items from `items` into `bound_queue` until it is full.
  """
  def push_front_until_maximum_size(
        %__MODULE__{size: maximum_size, maximum_size: maximum_size} = bound_queue,
        remaining
      ),
      do: {bound_queue, remaining}

  def push_front_until_maximum_size(%__MODULE__{} = bound_queue, [] = remaining), do: {bound_queue, remaining}

  def push_front_until_maximum_size(%__MODULE__{} = bound_queue, [head | tail] = remaining) do
    case push_front(bound_queue, head) do
      {:ok, new_bound_queue} -> push_front_until_maximum_size(new_bound_queue, tail)
      {:error, :maximum_size} -> {bound_queue, remaining}
    end
  end

  @doc """
  Shrinks the queue to half its current `size` and sets that as its new `max_size`.
  """
  def shrink(%__MODULE__{size: size}) when size <= 1, do: {:error, :minimum_size}

  def shrink(%__MODULE__{size: size} = bound_queue) do
    shrink(bound_queue, div(size, 2))
  end

  @doc """
  Set queue maximum_size to nil
  """
  def expand(bound_queue) do
    %{bound_queue | maximum_size: nil}
  end

  @doc """
  Whether the queue was shrunk.
  """
  def shrunk?(%__MODULE__{maximum_size: nil}), do: false
  def shrunk?(%__MODULE__{}), do: true

  defp shrink(%__MODULE__{size: goal_size} = bound_queue, goal_size) do
    {:ok, %__MODULE__{bound_queue | maximum_size: goal_size}}
  end

  defp shrink(%__MODULE__{} = bound_queue, goal_size) do
    {:ok, shrunk_bound_queue} = drop_back(bound_queue)
    shrink(shrunk_bound_queue, goal_size)
  end

  defimpl Enumerable do
    def count(%@for{size: size}), do: {:ok, size}

    def member?(%@for{queue: queue}, element) do
      {:ok, :queue.member(element, queue)}
    end

    def reduce(%@for{}, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(%@for{} = bound_queue, {:suspend, acc}, fun) do
      {:suspend, acc, &reduce(bound_queue, &1, fun)}
    end

    def reduce(%@for{size: 0}, {:cont, acc}, _fun), do: {:done, acc}

    def reduce(%@for{} = bound_queue, {:cont, acc}, fun) do
      {:ok, {head, tail_bound_queue}} = @for.pop_front(bound_queue)
      reduce(tail_bound_queue, fun.(head, acc), fun)
    end

    def slice(%@for{}), do: {:error, __MODULE__}
  end
end
