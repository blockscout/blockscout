defmodule Explorer.Chain.Cache.Counters.Stability.ValidatorsCount do
  @moduledoc """
  Counts and store counters of validators stability.

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

  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability

  @validators_counter_key "stability_validators_counter"
  @new_validators_counter_key "new_stability_validators_counter"
  @active_validators_counter_key "active_stability_validators_counter"

  @doc """
  Starts a process to periodically update validators stability counters
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, %{consolidate?: @enable_consolidation}, {:continue, :ok}}
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
  Fetches values for a stability validators counters from the `last_fetched_counters` table.
  """
  @spec get_counters(Keyword.t()) :: map()
  def get_counters(options) do
    %{
      validators_counter: LastFetchedCounter.get(@validators_counter_key, options),
      new_validators_counter: LastFetchedCounter.get(@new_validators_counter_key, options),
      active_validators_counter: LastFetchedCounter.get(@active_validators_counter_key, options)
    }
  end

  @doc """
  Consolidates the info by populating the `last_fetched_counters` table with the current database information.
  """
  @spec consolidate() :: any()
  def consolidate do
    tasks = [
      Task.async(fn -> ValidatorStability.count_validators() end),
      Task.async(fn -> ValidatorStability.count_new_validators() end),
      Task.async(fn -> ValidatorStability.count_active_validators() end)
    ]

    [validators_counter, new_validators_counter, active_validators_counter] = Task.await_many(tasks, :infinity)

    LastFetchedCounter.upsert(%{
      counter_type: @validators_counter_key,
      value: validators_counter
    })

    LastFetchedCounter.upsert(%{
      counter_type: @new_validators_counter_key,
      value: new_validators_counter
    })

    LastFetchedCounter.upsert(%{
      counter_type: @active_validators_counter_key,
      value: active_validators_counter
    })
  end
end
