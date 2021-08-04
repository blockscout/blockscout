defmodule Indexer.Prometheus.RPCInstrumenter do
  @moduledoc """
  Instrument histogram for json-rpc response times
  """
  use Prometheus.Metric
  require Logger

  def setup do
    Histogram.new(
      name: :http_request_duration_milliseconds,
      buckets: [20, 50, 70, 100, 200, 300, 500, 1000],
      duration_unit: false,
      labels: [:method, :status_code],
      help: "Http Request execution time."
    )
  end

  def instrument(%{time: time, method: method, status_code: status_code}) do
    Histogram.observe(
      [name: :http_request_duration_milliseconds, labels: [method, status_code]],
      time
    )
  end
end
