defmodule Indexer.Prometheus.BlockInstrumenter do
  @moduledoc """
  Instrument block related metrics.
  """
  use Prometheus.Metric

  def setup do
    counter_events = [
      [:reorgs]
    ]

    gauge_events = [
      [:pending],
      [:average_time],
      [:last_block_age],
      [:last_block_number],
      [:pending_blockcount]
    ]

    Enum.each(counter_events, &setup_counter/1)
    Enum.each(gauge_events, &setup_gauge/1)
  end

  defp setup_counter(event) do
    name = "indexer_blocks_#{Enum.join(event, "_")}"

    Counter.declare(
      name: String.to_atom("#{name}_total"),
      help: "Total count of tracking for block event #{name}"
    )

    :telemetry.attach(name, [:indexer, :blocks | event], &handle_inc_event/4, nil)
  end

  defp setup_gauge(event) do
    name = "indexer_blocks_#{Enum.join(event, "_")}"

    Gauge.declare(
      name: String.to_atom("#{name}_current"),
      help: "Current number of tracking for block event #{name}"
    )

    :telemetry.attach(name, [:indexer, :blocks | event], &handle_set_event/4, nil)
  end

  def handle_inc_event([:indexer, :blocks, :reorgs], _value, _metadata, _config) do
    Counter.inc(name: :indexer_blocks_reorgs_total)
  end

  def handle_set_event([:indexer, :blocks, :pending], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_blocks_pending_current], val)
  end

  def handle_set_event([:indexer, :blocks, :average_time], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_blocks_average_time_current], val)
  end

  def handle_set_event([:indexer, :blocks, :last_block_age], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_blocks_last_block_age_current], val)
  end

  def handle_set_event([:indexer, :blocks, :last_block_number], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_blocks_last_block_number_current], val)
  end

  def handle_set_event([:indexer, :blocks, :pending_blockcount], %{value: val}, _metadata, _config) do
    Gauge.set([name: :indexer_blocks_pending_blockcount_current], val)
  end
end
