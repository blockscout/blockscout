defmodule Explorer.Celo.Telemetry.Instrumentation do
  @moduledoc "A behaviour to define metrics for a given area"

  @doc "Returns a list of metrics implemented by this module"
  @callback metrics() :: [Telemetry.Metrics.t()]

  defmacro __using__(_opts) do
    quote do
      import Telemetry.Metrics
      @behaviour Explorer.Celo.Telemetry.Instrumentation
    end
  end
end
