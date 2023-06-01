defmodule BlockScoutWeb.Counters.BlocksIndexedCounter do
  @moduledoc """
  Module responsible for fetching and consolidating the number blocks indexed.

  It loads the count asynchronously in a time interval.
  """

  use GenServer

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain

  # It is undesirable to automatically start the counter in all environments.
  # Consider the test environment: if it initiates but does not finish before a
  # test ends, that test will fail.
  config = Application.compile_env(:block_scout_web, __MODULE__)
  @enabled Keyword.get(config, :enabled)

  @doc """
  Starts a process to periodically update the % of blocks indexed.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(args) do
    if @enabled do
      Task.start_link(&calculate_blocks_indexed/0)

      schedule_next_consolidation()
    end

    {:ok, args}
  end

  def calculate_blocks_indexed do
    indexed_ratio_blocks = Chain.indexed_ratio_blocks()

    finished? = Chain.finished_indexing?(indexed_ratio_blocks)

    Notifier.broadcast_blocks_indexed_ratio(indexed_ratio_blocks, finished?)
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :calculate_blocks_indexed, :timer.minutes(5))
  end

  @impl true
  def handle_info(:calculate_blocks_indexed, state) do
    calculate_blocks_indexed()

    schedule_next_consolidation()

    {:noreply, state}
  end
end
