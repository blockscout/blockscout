# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Prometheus.RealtimeMetrics do
  @moduledoc """
  Module responsible for periodically setting realtime indexing delay metrics.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.Metrics.Queries.IndexerMetrics, as: IndexerMetricsQueries
  alias Indexer.Prometheus.Instrumenter

  @interval :timer.minutes(5)

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

  defp set_metrics do
    [
      {:erc20_token_balances_realtime_indexing_delay_percentiles,
       :erc20_token_balances_realtime_indexing_delay_seconds},
      {:blocks_realtime_indexing_delay_percentiles, :blocks_realtime_indexing_delay_seconds}
    ]
    |> Enum.map(fn {query_fn, metric_fn} ->
      Task.async(fn ->
        percentiles = apply(IndexerMetricsQueries, query_fn, [])
        apply(Instrumenter, metric_fn, [percentiles])
      end)
    end)
    |> Task.yield_many(:timer.minutes(5))
    |> Enum.each(fn {task, res} ->
      case res do
        {:ok, _} ->
          :ok

        {:exit, reason} ->
          Logger.error("Query fetching realtime indexer metrics terminated: #{inspect(reason)}")

        nil ->
          Task.shutdown(task, :brutal_kill)
          Logger.error("Query fetching realtime indexer metrics timed out.")
      end
    end)
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
