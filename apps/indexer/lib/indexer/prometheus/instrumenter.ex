defmodule Indexer.Prometheus.Instrumenter do
  @moduledoc """
  Instrument prometheus metrics
  """
  use Prometheus.PlugPipelineInstrumenter
end
