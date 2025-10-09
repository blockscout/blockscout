defmodule BlockScoutWeb.Prometheus.PublicExporter do
  @moduledoc """
  Exports `Prometheus` metrics at `/public-metrics`
  """

  @dialyzer :no_match

  use Prometheus.PlugExporter
end
