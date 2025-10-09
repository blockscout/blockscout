defmodule Explorer.Chain.Cache.Counters.NewPendingTransactionsCount do
  @moduledoc """
  Caches number of pending transactions for last 30 minutes.

  It loads the sum asynchronously and in a time interval of :cache_period (default to 5 minutes).
  """

  use GenServer

  import Ecto.Query

  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @counter_type "pending_transaction_count_30min"

  @doc """
  Starts a process to periodically update the counter.
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
    Process.send_after(self(), :consolidate, cache_interval())
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
    query =
      from(transaction in Transaction,
        where: is_nil(transaction.block_hash) and transaction.inserted_at >= ago(30, "minute"),
        select: count(transaction.hash)
      )

    count = Repo.one!(query, timeout: :infinity)

    LastFetchedCounter.upsert(%{
      counter_type: @counter_type,
      value: count
    })
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, #{__MODULE__}, enable_consolidation: true`

  to:

  `config :explorer, #{__MODULE__}, enable_consolidation: false`
  """
  def enable_consolidation?, do: Application.get_env(:explorer, __MODULE__)[:enable_consolidation]

  defp cache_interval, do: Application.get_env(:explorer, __MODULE__)[:cache_period]
end
