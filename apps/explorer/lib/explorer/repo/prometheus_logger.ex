defmodule Explorer.Repo.PrometheusLogger do
  @moduledoc """
  Log `Ecto` query durations as `Prometheus` metrics.
  """

  @dialyzer {:no_match, [log: 1, setup: 0]}

  use Prometheus.EctoInstrumenter
end
