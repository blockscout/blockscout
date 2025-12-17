defmodule Indexer.Prometheus.Metrics do
  @moduledoc """
  Module responsible for periodically setting indexer metrics.
  """

  use GenServer

  alias Explorer.Chain.Metrics.Queries.IndexerMetrics, as: IndexerMetricsQueries
  alias Indexer.Prometheus.Instrumenter

  @interval :timer.hours(1)
  @default_metrics_list [
    :missing_blocks_count,
    :missing_internal_transactions_count,
    :multichain_search_db_main_export_queue_count,
    :multichain_search_db_export_balances_queue_count,
    :multichain_search_db_export_counters_queue_count,
    :multichain_search_db_export_token_info_queue_count
  ]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    if Application.get_env(:indexer, __MODULE__)[:enabled] do
      send(self(), :set_metrics)
      {:ok, %{}}
    else
      :ignore
    end
  end

  def handle_info(:set_metrics, state) do
    schedule_next_run()
    set_metrics()

    {:noreply, state}
  end

  defp metrics_list do
    additional_metrics =
      Application.get_env(:indexer, __MODULE__)[:specific_metrics_enabled?]
      |> Enum.filter(fn {_, enabled?} -> enabled? == true end)
      |> Enum.map(fn {metric, _} -> metric end)

    @default_metrics_list ++ additional_metrics
  end

  defp set_metrics do
    metrics_list()
    |> Enum.map(fn metric ->
      Task.async(fn ->
        set_handler_metric(metric)
      end)
    end)
    |> Task.yield_many(:timer.hours(1))
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching indexer metrics terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching indexer metrics timed out."
      end
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp set_handler_metric(metric) do
    func = String.to_atom(to_string(metric))

    items_count =
      IndexerMetricsQueries
      |> apply(func, [])

    apply(Instrumenter, metric, [items_count])
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
