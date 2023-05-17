defmodule Explorer.Utility.MissingRangesManipulator do
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

  def clear_batch(batch) do
    GenServer.call(__MODULE__, {:clear_batch, batch}, timeout(batch))
  end

  def save_batch(batch) do
    GenServer.call(__MODULE__, {:save_batch, batch}, timeout(batch))
  end

  def add_ranges_by_block_numbers(numbers) do
    GenServer.cast(__MODULE__, {:add_ranges_by_block_numbers, numbers})
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_latest_batch, _from, state) do
    {:reply, MissingBlockRange.get_latest_batch(), state}
  end

  def handle_call({:clear_batch, batch}, _from, state) do
    {:reply, MissingBlockRange.clear_batch(batch), state}
  end

  def handle_call({:save_batch, batch}, _from, state) do
    {:reply, MissingBlockRange.save_batch(batch), state}
  end

  @impl true
  def handle_cast({:add_ranges_by_block_numbers, numbers}, state) do
    MissingBlockRange.add_ranges_by_block_numbers(numbers)

    {:noreply, state}
  end

  @default_timeout 5000
  @timeout_by_range 2000
  defp timeout(batch) do
    @default_timeout + @timeout_by_range * Enum.count(batch)
  end
end
