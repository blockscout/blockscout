defmodule EventStream.Metrics do
  @moduledoc "Instrumentation for eventstream app"

  alias Explorer.Celo.Telemetry.Instrumentation
  use Instrumentation

  def metrics do
    [
      counter("blockscout.event_stream.flush")
    ]
  end
end
