defmodule Indexer.Stack do
  @moduledoc """
  Combine prometheus exporter with the health plug
  """
  use Plug.Builder

  plug(Indexer.Prometheus.Exporter)
  plug(Indexer.Health.Plug, [])
end
