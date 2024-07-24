defmodule Explorer.Counters.Transactions24hStats do
  @moduledoc """
  Caches number of transactions for last 24 hours, sum of transaction fees for last 24 hours and average transaction fee for last 24 hours counters.

  It loads the counters asynchronously and in a time interval of :cache_period (default to 1 hour).
  """

  use GenServer

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Transaction

  @tx_count_name "transaction_count_24h"
  @tx_fee_sum_name "transaction_fee_sum_24h"
  @tx_fee_average_name "transaction_fee_average_24h"

  @doc """
  Starts a process to periodically update the counters.
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
  Fetches the value for a `#{@tx_count_name}` counter type from the `last_fetched_counters` table.
  """
  def fetch_count(options) do
    Chain.get_last_fetched_counter(@tx_count_name, options)
  end

  @doc """
  Fetches the value for a `#{@tx_fee_sum_name}` counter type from the `last_fetched_counters` table.
  """
  def fetch_fee_sum(options) do
    Chain.get_last_fetched_counter(@tx_fee_sum_name, options)
  end

  @doc """
  Fetches the value for a `#{@tx_fee_average_name}` counter type from the `last_fetched_counters` table.
  """
  def fetch_fee_average(options) do
    Chain.get_last_fetched_counter(@tx_fee_average_name, options)
  end

  @doc """
  Consolidates the info by populating the `last_fetched_counters` table with the current database information.
  """
  def consolidate do
    fee_query =
      dynamic(
        [transaction, block],
        fragment(
          "COALESCE(?, ? + LEAST(?, ?))",
          transaction.gas_price,
          block.base_fee_per_gas,
          transaction.max_priority_fee_per_gas,
          transaction.max_fee_per_gas - block.base_fee_per_gas
        ) * transaction.gas_used
      )

    sum_query = dynamic([_, _], sum(^fee_query))
    avg_query = dynamic([_, _], avg(^fee_query))

    query =
      from(transaction in Transaction,
        join: block in assoc(transaction, :block),
        where: block.timestamp >= ago(24, "hour"),
        select: %{count: count(transaction.hash)},
        select_merge: ^%{fee_sum: sum_query},
        select_merge: ^%{fee_average: avg_query}
      )

    %{
      count: count,
      fee_sum: fee_sum,
      fee_average: fee_average
    } = Repo.one!(query, timeout: :infinity)

    Chain.upsert_last_fetched_counter(%{
      counter_type: @tx_count_name,
      value: count
    })

    Chain.upsert_last_fetched_counter(%{
      counter_type: @tx_fee_sum_name,
      value: fee_sum
    })

    Chain.upsert_last_fetched_counter(%{
      counter_type: @tx_fee_average_name,
      value: fee_average
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
