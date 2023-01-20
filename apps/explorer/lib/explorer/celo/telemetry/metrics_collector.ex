defmodule Explorer.Celo.Telemetry.MetricsCollector do
  @moduledoc "A process to collect metrics for later exposure on a prometheus endpoint"

  use Supervisor
  import Telemetry.Metrics

  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  # Accepts a list of metrics, either directly in the form of a list of Telemetry.Metrics or a module with a `metrics()` function
  def init(arg) do
    metrics = Keyword.get(arg, :metrics, [])
    Supervisor.init(child_processes(metrics), strategy: :one_for_one)
  end

  defp collector_metrics do
    [
      counter("blockscout.metrics.scrape.count")
    ]
  end

  defp child_processes(metrics) do
    [
      {TelemetryMetricsPrometheus.Core, metrics: get_metrics(metrics)}
    ]
  end

  defp get_metrics(metrics) do
    [collector_metrics() | metrics]
    |> Enum.map(fn
      m when is_list(m) -> m
      module when is_atom(module) -> module.metrics()
    end)
    |> List.flatten()
  end
end
