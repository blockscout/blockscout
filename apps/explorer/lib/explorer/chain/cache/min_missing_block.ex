defmodule Explorer.Chain.Cache.MinMissingBlockNumber do
  @moduledoc """
  Caches min missing block number (break in the chain).
  """

  use GenServer

  alias Explorer.Chain

  @doc """
  Starts a process to periodically update the % of blocks indexed.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(args) do
    Task.start_link(&fetch_min_missing_block/0)

    schedule_next_consolidation()

    {:ok, args}
  end

  def fetch_min_missing_block do
    result = Chain.fetch_min_missing_block_cache()

    unless is_nil(result) do
      params = %{
        counter_type: "min_missing_block_number",
        value: result
      }

      Chain.upsert_last_fetched_counter(params)
    end
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :fetch_min_missing_block, :timer.minutes(20))
  end

  @impl true
  def handle_info(:fetch_min_missing_block, state) do
    fetch_min_missing_block()

    schedule_next_consolidation()

    {:noreply, state}
  end
end
