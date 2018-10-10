defmodule Indexer.Memory.Shrinkable do
  @moduledoc """
  A process that can shrink its memory usage when asked by `Indexer.Memory.Monitor`.

  Processes need to `handle_call(:shrink, from, state)`.
  """

  @doc """
  Asks `pid` to shrink its memory usage.
  """
  @spec shrink(pid()) :: :ok
  def shrink(pid) when is_pid(pid) do
    GenServer.call(pid, :shrink)
  end
end
