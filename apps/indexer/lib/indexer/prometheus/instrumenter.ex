defmodule Indexer.Prometheus.Instrumenter do
  @moduledoc """
  Blockchain data fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @rollups [:arbitrum, :zksync, :optimism, :polygon_zkevm, :scroll]

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

  @gauge [name: :memory_consumed, labels: [:fetcher], help: "Amount of memory consumed by fetchers (MB)"]

  @gauge [name: :latest_block_number, help: "Latest block number"]

  @gauge [name: :latest_block_timestamp, help: "Latest block timestamp"]

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

  def set_memory_consumed(fetcher, memory) do
    Gauge.set([name: :memory_consumed, labels: [fetcher]], memory)
  end

  defp latest_block_number(number) do
    Gauge.set([name: :latest_block_number], number)
  end

  defp latest_block_timestamp(timestamp) do
    Gauge.set([name: :latest_block_timestamp], timestamp)
  end

  @doc """
  Generates the latest block number and timestamp Prometheus metrics.

  ## Parameters

    - `number`: The block number to set.
    - `timestamp`: The timestamp of the block as a `DateTime` struct.
  """
  @spec set_latest_block(number :: integer, timestamp :: DateTime.t()) :: :ok
  def set_latest_block(number, timestamp) do
    latest_block_number(number)
    latest_block_timestamp(DateTime.to_unix(timestamp))
  end

  if @chain_type in @rollups do
    @gauge [name: :latest_batch_number, help: "L2 latest batch number"]

    @gauge [name: :latest_batch_timestamp, help: "L2 latest batch timestamp"]

    defp latest_batch_number(number) do
      Gauge.set([name: :latest_batch_number], number)
    end

    defp latest_batch_timestamp(timestamp) do
      Gauge.set([name: :latest_batch_timestamp], timestamp)
    end

    @doc """
    Generates the latest batch number and timestamp Prometheus metrics.

    ## Parameters

      - `number`: The batch number to set.
      - `timestamp`: The timestamp of the batch as a `DateTime` struct.
    """
    @spec set_latest_batch(number :: integer, timestamp :: DateTime.t()) :: :ok
    def set_latest_batch(number, timestamp) do
      latest_batch_number(number)
      latest_batch_timestamp(DateTime.to_unix(timestamp))
    end
  else
    @doc """
    Generates the latest batch number and timestamp Prometheus metrics.

    ## Parameters

      - `number`: The batch number to set.
      - `timestamp`: The timestamp of the batch as a `DateTime` struct.
    """
    @spec set_latest_batch(number :: integer, timestamp :: DateTime.t()) :: :ok
    def set_latest_batch(_number, _timestamp) do
      :ok
    end
  end
end
