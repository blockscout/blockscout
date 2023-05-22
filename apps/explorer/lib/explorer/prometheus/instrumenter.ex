defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @histogram [
    name: :block_import_stage_runner_duration_microseconds,
    labels: [:stage, :runner, :step],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block import stage, runner and step in runner processing time"
  ]

  def block_import_stage_runner(function, stage, runner, step) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end
end
