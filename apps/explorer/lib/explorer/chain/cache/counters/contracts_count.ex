defmodule Explorer.Chain.Cache.Counters.ContractsCount do
  @moduledoc """
  Caches the number of contracts.

  It loads the count asynchronously and in a time interval of 30 minutes.
  """

  use GenServer
  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  use Utils.CompileTimeEnvHelper,
    enable_consolidation: [:explorer, [__MODULE__, :enable_consolidation]],
    update_interval_in_milliseconds: [:explorer, [__MODULE__, :update_interval_in_milliseconds]]

  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter

  @counter_type "contracts_count"

  @doc """
  Starts a process to periodically update the counter of all the contracts.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, %{consolidate?: enable_consolidation?()}, {:continue, :ok}}
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :consolidate, @update_interval_in_milliseconds)
  end

  @impl true
  def handle_continue(:ok, %{consolidate?: true} = state) do
    consolidate()
    schedule_next_consolidation()

    {:noreply, state}
  end

  @impl true
  def handle_continue(:ok, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:consolidate, state) do
    consolidate()
    schedule_next_consolidation()

    {:noreply, state}
  end

  @doc """
  Fetches the value for a `#{@counter_type}` counter type from the `last_fetched_counters` table.
  """
  def fetch(options) do
    LastFetchedCounter.get(@counter_type, options)
  end

  @doc """
  Consolidates the info by populating the `last_fetched_counters` table with the current database information.
  """
  def consolidate do
    all_counter = Chain.count_contracts()

    params = %{
      counter_type: @counter_type,
      value: all_counter
    }

    LastFetchedCounter.upsert(params)
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Chain.Cache.Counters.ContractsCount, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Chain.Cache.Counters.ContractsCount, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
