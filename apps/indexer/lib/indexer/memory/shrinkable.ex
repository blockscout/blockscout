defmodule Indexer.Memory.Shrinkable do
  @moduledoc """
  A process that can shrink its memory usage when asked by `Indexer.Memory.Monitor`.

  Processes need to `handle_call(:shrink, from, state)`.
  """

  @doc """
  Asks `pid` to shrink its memory usage.
  """
  @spec shrink(pid()) :: :ok | {:error, :minimum_size}
  def shrink(pid) when is_pid(pid) do
    GenServer.call(pid, :shrink)
  end

  @doc """
  Asks `pid` if it was shrunk in the past.

  `pid` will only return `true` if it returned `:ok` from `shrink/1`.
  """
  @spec shrunk?(pid()) :: boolean()
  def shrunk?(pid) when is_pid(pid) do
    GenServer.call(pid, :shrunk?)
  end
end
