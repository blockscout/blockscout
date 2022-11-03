defmodule Indexer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @histogram [
    name: :block_full_processing_duration_microseconds,
    labels: [:fetcher],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block whole processing time including fetch and import"
  ]

  @histogram [
    name: :block_import_duration_microseconds,
    labels: [:fetcher],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block import time"
  ]

  @histogram [
    name: :block_batch_fetch_request_duration_microseconds,
    labels: [:fetcher],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block fetch batch request processing time"
  ]

  @gauge [name: :missing_block_count, help: "Number of missing blocks in the database"]

  @gauge [name: :delay_from_last_node_block, help: "Delay from the last block on the node in seconds"]

  @counter [name: :import_errors_count, help: "Number of database import errors"]

  def block_full_process(time, fetcher) do
    Histogram.observe([name: :block_full_processing_duration_microseconds, labels: [fetcher]], time)
  end

  def block_import(time, fetcher) do
    Histogram.observe([name: :block_import_duration_microseconds, labels: [fetcher]], time)
  end

  def block_batch_fetch(time, fetcher) do
    Histogram.observe([name: :block_batch_fetch_request_duration_microseconds, labels: [fetcher]], time)
  end

  def missing_blocks(missing_block_count) do
    Gauge.set([name: :missing_block_count], missing_block_count)
  end

  def node_delay(delay) do
    Gauge.set([name: :delay_from_last_node_block], delay)
  end

  def import_errors(error_count \\ 1) do
    Counter.inc([name: :import_errors_count], error_count)
  end
end
