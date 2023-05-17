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

  @timeout_by_range 2000
  def clear_batch(batch) do
    GenServer.call(__MODULE__, {:clear_batch, batch}, @timeout_by_range * Enum.count(batch))
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

  def handle_call({:clear_batch, batch}, _from, state) do
    {:reply, MissingBlockRange.clear_batch(batch), state}
  end
end
