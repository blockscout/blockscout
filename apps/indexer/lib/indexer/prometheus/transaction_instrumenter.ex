defmodule Indexer.Prometheus.TransactionInstrumenter do
  @moduledoc """
  Instrument transaction related metrics.
  """
  use Prometheus.Metric

  def setup do
    events = [
      [:pending],
      [:total]
    ]

    Enum.each(events, &setup_event/1)
  end

  defp setup_event(event) do
    name = "indexer_transactions_#{Enum.join(event, "_")}"

    Gauge.declare(
      name: String.to_atom("#{name}_current"),
      help: "Current number of tracking for transaction event #{name}"
    )

    :telemetry.attach(name, [:indexer, :transactions | event], &handle_event/4, nil)
  end

  def handle_event([:indexer, :transactions, :pending], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_transactions_pending_current], val)
  end

  def handle_event([:indexer, :transactions, :total], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_transactions_total_current], val)
  end
end
