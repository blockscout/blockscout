defmodule Explorer.Chain.Cache.Counters.AddressesCount do
  @moduledoc """
  Caches the number of all addresses.

  It loads the count asynchronously and in a time interval of 30 minutes.
  """

  use GenServer
  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  use Utils.CompileTimeEnvHelper,
    enable_consolidation: [:explorer, [__MODULE__, :enable_consolidation]]

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Repo

  @table_name :addresses_counter

  @cache_key "addresses_count"

  @doc """
  Starts a process to periodically update the counter of the token holders.
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
    opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true
    ]

    :ets.new(@table_name, opts)
  end

  defp schedule_next_consolidation do
    Process.send_after(
      self(),
      :consolidate,
      Application.get_env(:explorer, __MODULE__)[:update_interval_in_milliseconds]
    )
  end

  @doc """
  Inserts new items into the `:ets` table.
  """
  def insert_counter({key, info}) do
    :ets.insert(@table_name, {key, info})
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
    do_fetch(:ets.lookup(@table_name, @cache_key))
  end

  defp do_fetch([{_, result}]), do: result

  defp do_fetch([]) do
    CacheCountersHelper.evaluate_count(@cache_key, nil, :estimated_addresses_count)
  end

  @doc """
  Consolidates the info by populating the `:ets` table with the current database information.
  """
  def consolidate do
    counter = Repo.aggregate(Address, :count, timeout: :infinity)

    params = %{
      counter_type: @cache_key,
      value: counter
    }

    LastFetchedCounter.upsert(params)

    insert_counter({@cache_key, counter})
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Chain.Cache.Counters.AddressesCount, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Chain.Cache.Counters.AddressesCount, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
