defmodule Indexer.Prometheus.GenericInstrumenter do
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
    name = "indexer_generics_#{Enum.join(event, "_")}"

    Counter.declare(
      name: String.to_atom("#{name}_total"),
      help: "Total count of tracking for generic event #{name}"
    )

    :telemetry.attach(name, [:indexer, :generics | event], &handle_event/4, nil)
  end

  def handle_event([:indexer, :generics, :error], _value, _metadata, _config) do
    Counter.inc(name: :indexer_generics_error_total)
  end
end
