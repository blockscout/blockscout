defmodule Indexer.Prometheus.MetricsCron do
  @moduledoc """
  Periodically retrieves and updates prometheus metrics
  """
  use GenServer
  alias EthereumJSONRPC.HTTP.RpcResponseEts
  alias Explorer.Celo.Metrics.{BlockchainMetrics, DatabaseMetrics}
  alias Explorer.Chain
  alias Explorer.Counters.AverageBlockTime
  alias Indexer.Prometheus.RPCInstrumenter
  alias Timex.Duration

  require DateTime
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    repeat()
    {:ok, %{running_operations: []}}
  end

  defp config(key) do
    Application.get_env(:indexer, __MODULE__, [])[key]
  end

  @metric_operations [
    :pending_transactions,
    :block_age_and_gas_metrics,
    :average_block_time,
    :pending_block_count,
    :number_of_locks,
    :number_of_deadlocks,
    :longest_query_duration,
    :rpc_response_times,
    :transaction_count,
    :address_count,
    :total_token_supply
  ]

  @impl true
  def handle_info(:import_and_reschedule, %{running_operations: running} = state) do
    unless running == [] do
      Logger.info("MetricsCron scheduled, tasks still running: #{Enum.join(running, ",")}")
    end

    running_operations =
      @metric_operations
      |> Enum.filter(&(!Enum.member?(running, &1)))
      |> Enum.map(fn operation ->
        Task.Supervisor.async_nolink(Indexer.Prometheus.MetricsCron.TaskSupervisor, fn ->
          apply(__MODULE__, operation, [])
          {:completed, operation}
        end)

        operation
      end)

    repeat()

    {:noreply, %{state | running_operations: running_operations}}
  end

  @impl true
  def handle_info({_task_ref, {:completed, operation}}, %{running_operations: ops} = state) do
    {:noreply, %{state | running_operations: List.delete(ops, operation)}}
  end

  @impl true
  def handle_info({:DOWN, _, _, _, :normal}, state), do: {:noreply, state}

  @impl true
  def handle_info({:DOWN, _, _, _, failure_message}, state) do
    Logger.error("MetricsCron task received an error: #{failure_message |> inspect()}")
    {:noreply, state}
  end

  def pending_transactions do
    pending_transactions_count = Chain.pending_transactions_count()
    :telemetry.execute([:indexer, :transactions, :pending], %{value: pending_transactions_count})
  end

  def average_block_time do
    average_block_time = AverageBlockTime.average_block_time()
    :telemetry.execute([:indexer, :blocks, :average_time], %{value: Duration.to_seconds(average_block_time)})
  end

  def pending_block_count do
    pending_block_count = BlockchainMetrics.pending_blockcount()
    :telemetry.execute([:indexer, :blocks, :pending_blockcount], %{value: pending_block_count})
  end

  def number_of_locks do
    number_of_locks = DatabaseMetrics.fetch_number_of_locks()
    :telemetry.execute([:indexer, :db, :locks], %{value: number_of_locks})
  end

  def number_of_deadlocks do
    number_of_dead_locks = DatabaseMetrics.fetch_number_of_dead_locks()
    :telemetry.execute([:indexer, :db, :deadlocks], %{value: number_of_dead_locks})
  end

  def longest_query_duration do
    longest_query_duration = DatabaseMetrics.fetch_name_and_duration_of_longest_query()
    :telemetry.execute([:indexer, :db, :longest_query_duration], %{value: longest_query_duration})
  end

  def rpc_response_times do
    response_times = RpcResponseEts.get_all()

    response_times
    |> Enum.filter(&Map.has_key?(elem(&1, 1), :finish))
    |> Enum.map(&elem(&1, 0))
    |> Enum.each(&calculate_and_add_rpc_response_metrics(&1, :proplists.get_all_values(&1, response_times)))
  end

  def transaction_count do
    total_transaction_count = Chain.transaction_estimated_count()
    :telemetry.execute([:indexer, :transactions, :total], %{value: total_transaction_count})
  end

  def address_count do
    total_address_count = Chain.address_estimated_count()
    :telemetry.execute([:indexer, :tokens, :address_count], %{value: total_address_count})
  end

  def total_token_supply do
    with total_supply when not is_nil(total_supply) <- Chain.total_supply() do
      case total_supply do
        0 -> :telemetry.execute([:indexer, :tokens, :total_supply], %{value: 0})
        _ -> :telemetry.execute([:indexer, :tokens, :total_supply], %{value: Decimal.to_float(total_supply)})
      end
    end
  end

  def block_age_and_gas_metrics do
    {last_n_blocks_count, last_block_age, last_block_number, average_gas_used} =
      BlockchainMetrics.metrics_fetcher(config(:metrics_fetcher_blocks_count))

    :telemetry.execute([:indexer, :blocks, :pending], %{
      value: config(:metrics_fetcher_blocks_count) - last_n_blocks_count
    })

    :telemetry.execute([:indexer, :tokens, :average_gas], %{value: average_gas_used})

    :telemetry.execute([:indexer, :blocks, :last_block_age], %{value: last_block_age})

    :telemetry.execute([:indexer, :blocks, :last_block_number], %{value: last_block_number})
  end

  defp calculate_and_add_rpc_response_metrics(id, [start, finish]) do
    RPCInstrumenter.instrument(%{
      time: Map.get(finish, :finish) - Map.get(start, :start),
      method: Map.get(start, :method),
      status_code: Map.get(finish, :status_code)
    })

    RpcResponseEts.delete(id)
  end

  defp repeat do
    {interval, _} = Integer.parse(config(:metrics_cron_interval))
    Process.send_after(self(), :import_and_reschedule, :timer.seconds(interval))
  end
end
