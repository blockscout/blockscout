defmodule Explorer.Chain.Cache.Counters.WithdrawalsSum do
  @moduledoc """
  Caches the sum of all withdrawals.

  It loads the sum asynchronously and in a time interval of 30 minutes.
  """

  use GenServer

  use Utils.CompileTimeEnvHelper,
    enable_consolidation: [:explorer, [__MODULE__, :enable_consolidation]],
    update_interval_in_milliseconds: [:explorer, [__MODULE__, :update_interval_in_milliseconds]]

  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Wei

  @counter_type "withdrawals_sum"

  @doc """
  Starts a process to periodically update the sum of withdrawals.
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
    withdrawals_sum = Chain.sum_withdrawals()

    params = %{
      counter_type: @counter_type,
      value: (withdrawals_sum && Wei.to(withdrawals_sum, :wei)) || 0
    }

    LastFetchedCounter.upsert(params)
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, #{__MODULE__}, enable_consolidation: true`

  to:

  `config :explorer, #{__MODULE__}, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
