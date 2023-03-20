defmodule BlockScoutWeb.Counters.InternalTransactionsIndexedCounter do
  @moduledoc """
  Module responsible for fetching and consolidating the number pending block operations (internal transactions) indexed.

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
  Starts a process to periodically update the % of internal transactions indexed.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(args) do
    if @enabled do
      Task.start_link(&calculate_internal_transactions_indexed/0)

      schedule_next_consolidation()
    end

    {:ok, args}
  end

  def calculate_internal_transactions_indexed do
    ratio = Chain.indexed_ratio_internal_transactions()

    Notifier.broadcast_indexed_ratio("blocks:indexing_internal_transactions", ratio)
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :calculate_internal_transactions_indexed, :timer.minutes(7))
  end

  @impl true
  def handle_info(:calculate_internal_transactions_indexed, state) do
    calculate_internal_transactions_indexed()

    schedule_next_consolidation()

    {:noreply, state}
  end
end
