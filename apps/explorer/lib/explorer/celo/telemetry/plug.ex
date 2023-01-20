defmodule Explorer.Celo.Telemetry.Plug do
  @moduledoc """
   A plug to expose defined metrics to prometheus at endpoint /metrics

  Add this to an existing endpoint in order to expose prometheus metrics. Configuration of the endpoint (port, adaptor etc)
    is to be handled elsewhere. This approach is intended to work alongside an existing http endpoint, i.e. this will add a
  "/metrics" route to an endpoint which already serves content (like a health check service).
  """

  @behaviour Plug
  import Plug.Conn
  alias Explorer.Celo.Telemetry, as: Telemetry
  alias TelemetryMetricsPrometheus.Core, as: PrometheusCore

  # nop
  def init(_opts) do
  end

  @metrics_path "/metrics"

  def call(conn, _opts) do
    case conn.request_path do
      @metrics_path ->
        Telemetry.event([:metrics, :scrape])

        metrics = PrometheusCore.scrape()

        conn
        |> put_private(:prometheus_metrics_name, :prometheus_metrics)
        |> put_resp_content_type("text/plain")
        |> send_resp(200, metrics)
        |> halt()

      _ ->
        conn
    end
  end
end
