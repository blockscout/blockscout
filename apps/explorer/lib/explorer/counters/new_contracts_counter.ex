defmodule Explorer.Counters.NewContractsCounter do
  @moduledoc """
  Caches the number of contracts, new and verified.

  It loads the count asynchronously and in a time interval of 30 minutes.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Counters.Helper

  @table :new_contracts_counter

  @cache_key "new"

  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  config = Application.compile_env(:explorer, Explorer.Counters.NewContractsCounter)
  @enable_consolidation Keyword.get(config, :enable_consolidation)

  @update_interval_in_seconds Keyword.get(config, :update_interval_in_seconds)

  @doc """
  Starts a process to periodically update the counter of the .
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    create_table()

    {:ok, %{consolidate?: enable_consolidation?()}, {:continue, :ok}}
  end

  def create_table do
    Helper.create_cache_table(@table)
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :consolidate, :timer.seconds(@update_interval_in_seconds))
  end

  @doc """
  Inserts new items into the `:ets` table.
  """
  def insert_counter({key, info}) do
    :ets.insert(@table, {key, info})
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
  Fetches the info for a specific item from the `:ets` table.
  """
  def fetch do
    Helper.fetch_from_cache(@cache_key, @table)
  end

  @doc """
  Consolidates the info by populating the `:ets` table with the current database information.
  """
  def consolidate do
    new_all_counter = Chain.count_new_contracts()

    insert_counter({@cache_key, new_all_counter})
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Counters.NewContractsCounter, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Counters.NewContractsCounter, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
