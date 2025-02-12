defmodule Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount do
  @moduledoc """
  Caches number of transactions in last output root.

  It loads the count asynchronously and in a time interval of :cache_period (default to 5 minutes).
  """

  use GenServer

  import Ecto.Query

  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Optimism.OutputRoot
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @counter_type "last_output_root_size_count"

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
    LastFetchedCounter.get(@counter_type, options |> Keyword.put_new(:nullable, true))
  end

  @doc """
  Consolidates the info by populating the `last_fetched_counters` table with the current database information.
  """
  def consolidate do
    output_root_query =
      from(root in OutputRoot,
        select: {root.l2_block_number},
        order_by: [desc: root.l2_output_index],
        limit: 2
      )

    count =
      case output_root_query |> Repo.all() do
        [{last_block_number}, {prev_block_number}] ->
          query =
            from(transaction in Transaction,
              where:
                not is_nil(transaction.block_hash) and transaction.block_number > ^prev_block_number and
                  transaction.block_number <= ^last_block_number,
              select: count(transaction.hash)
            )

          Repo.one!(query, timeout: :infinity)

        _ ->
          nil
      end

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
