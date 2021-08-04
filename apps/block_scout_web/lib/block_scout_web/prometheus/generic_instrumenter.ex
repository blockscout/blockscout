defmodule BlockScoutWeb.Prometheus.GenericInstrumenter do
  @moduledoc """
  Instrument generic metrics.
  """
  use Prometheus.Metric

  def setup do
    events = [
      [:error]
    ]

    Enum.each(events, &setup_event/1)
  end

  defp setup_event(event) do
    name = "block_scout_web_generics_#{Enum.join(event, "_")}"

    Counter.declare(
      name: :block_scout_web_generics_error_total,
      help: "Total count of tracking for generic event #{name}"
    )

    :telemetry.attach(name, [:block_scout_web, :generics | event], &handle_event/4, nil)
  end

  def handle_event([:block_scout_web, :generics, :error], _value, _metadata, _config) do
    Counter.inc(name: :block_scout_web_generics_error_total)
  end
end
