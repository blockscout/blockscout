defmodule EthereumJSONRPC.Celo.Instrumentation do
  @moduledoc "Metric definitions for EthereumJSONRPC library"

  # not using Explorer.Celo.Telemetry.Instrumentation to prevent circular dependency

  import Telemetry.Metrics

  def metrics do
    [
      counter("ethereum_jsonrpc_http_request_start_count",
        event_name: [:ethereum_jsonrpc, :http_request, :start],
        measurement: :count,
        description: "Count of HTTP requests attempted"
      ),
      distribution("http_request_duration_milliseconds",
        reporter_options: [
          buckets: [
            100,
            500,
            :timer.seconds(1),
            :timer.seconds(10),
            :timer.minutes(1),
            :timer.minutes(2),
            :timer.minutes(3),
            :timer.minutes(5),
            :timer.minutes(10)
          ]
        ],
        event_name: [:ethereum_jsonrpc, :http_request, :stop],
        measurement: :duration,
        description: "Response times of requests sent via http to blockchain node",
        tags: [:method, :status_code],
        unit: {:native, :millisecond}
      )
    ]
  end
end
