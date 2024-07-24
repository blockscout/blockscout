defmodule BlockScoutWeb.Prometheus.Instrumenter do
  @moduledoc """
  BlockScoutWeb metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @gauge [
    name: :event_handler_queue_length,
    labels: [:handler],
    help: "Number of events in event handlers queue"
  ]

  def event_handler_queue_length(handler, length) do
    Gauge.set([name: :event_handler_queue_length, labels: [handler]], length)
  end
end
