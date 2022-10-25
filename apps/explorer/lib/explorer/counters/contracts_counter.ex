defmodule Explorer.Counters.ContractsCounter do
  @moduledoc """
  Caches the number of contracts, new and verified.

  It loads the count asynchronously and in a time interval of 30 minutes.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Counters.Helper

  @cache_name :contracts_counter

  @all "all"
  @verified "verified"
  @new_all "new"
  @new_verified "new_verified"

  @keys [@all, @verified, @new_all, @new_verified]

  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  config = Application.compile_env(:explorer, Explorer.Counters.ContractsCounter)
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
    Helper.create_cache_table(@cache_name)
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :consolidate, :timer.seconds(@update_interval_in_seconds))
  end

  @doc """
  Inserts new items into the `:ets` table.
  """
  def insert_counter({key, info}) do
    :ets.insert(@cache_name, {key, info})
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
  def fetch(key) when key in @keys do
    Helper.fetch_from_cache(key, @cache_name)
  end

  def fetch(_), do: 0

  @doc """
  Consolidates the info by populating the `:ets` table with the current database information.
  """
  def consolidate do
    all_counter = Chain.count_contracts()
    new_all_counter = Chain.count_new_contracts()
    verified_counter = Chain.count_verified_contracts()
    new_verified_counter = Chain.count_new_verified_contracts()

    insert_counter({@all, all_counter})
    insert_counter({@new_all, new_all_counter})
    insert_counter({@verified, verified_counter})
    insert_counter({@new_verified, new_verified_counter})
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Counters.AddressesCounter, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Counters.AddressesCounter, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
