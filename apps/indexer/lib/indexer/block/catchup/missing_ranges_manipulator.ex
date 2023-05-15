defmodule Indexer.Block.Catchup.MissingRangesManipulator do
  @moduledoc """
  Performs concurrent-safe actions on missing block ranges.
  """

  use GenServer

  alias Explorer.Utility.MissingBlockRange

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_latest_batch do
    GenServer.call(__MODULE__, :get_latest_batch)
  end

  def delete_range(range) do
    GenServer.cast(__MODULE__, {:delete_range, range})
  end

  def clear_batch(batch) do
    GenServer.cast(__MODULE__, {:clear_batch, batch})
  end

  @impl true
  def init(_) do
    MissingBlockRange.sanitize_missing_block_ranges()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_latest_batch, _from, state) do
    {:reply, MissingBlockRange.get_latest_batch(), state}
  end

  @impl true
  def handle_cast({:delete_range, range}, state) do
    MissingBlockRange.delete_range(range)

    {:noreply, state}
  end

  def handle_cast({:clear_batch, batch}, state) do
    MissingBlockRange.clear_batch(batch)

    {:noreply, state}
  end
end
