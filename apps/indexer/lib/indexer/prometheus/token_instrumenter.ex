defmodule Indexer.Prometheus.TokenInstrumenter do
  @moduledoc """
  Instrument token related metrics.
  """
  use Prometheus.Metric

  def setup do
    events = [
      [:address_count],
      [:total_supply],
      [:average_gas]
    ]

    Enum.each(events, &setup_event/1)
  end

  defp setup_event(event) do
    name = "indexer_tokens_#{Enum.join(event, "_")}"

    Gauge.declare(
      name: String.to_atom("#{name}_current"),
      help: "Current number of tracking for token event #{name}"
    )

    :telemetry.attach(name, [:indexer, :tokens | event], &handle_event/4, nil)
  end

  def handle_event([:indexer, :tokens, :address_count], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_tokens_address_count_current], val)
  end

  def handle_event([:indexer, :tokens, :total_supply], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_tokens_total_supply_current], val)
  end

  def handle_event([:indexer, :tokens, :average_gas], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_tokens_average_gas_current], val)
  end
end
