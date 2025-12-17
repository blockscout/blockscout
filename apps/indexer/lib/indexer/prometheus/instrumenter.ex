defmodule Indexer.Prometheus.Instrumenter do
  @moduledoc """
  Blockchain data fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric
  use Utils.RuntimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias EthereumJSONRPC.Utility.RangesHelper

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

  @gauge [name: :delay_from_last_node_block, help: "Delay from the last block on the node in seconds"]

  @counter [name: :import_errors_count, help: "Number of database import errors"]

  @gauge [name: :memory_consumed, labels: [:fetcher], help: "Amount of memory consumed by fetchers (MB)"]

  @gauge [name: :latest_block_number, help: "Latest block number"]

  @gauge [name: :latest_block_timestamp, help: "Latest block timestamp"]

  # metrics of indexing monitor
  @gauge [name: :missing_blocks_count, help: "Number of blocks missing in the chain"]
  @gauge [
    name: :missing_internal_transactions_count,
    help: "Number of blocks with not yet fetched internal transactions"
  ]
  @gauge [name: :missing_current_token_balances_count, help: "Number of missing current token balances"]
  @gauge [name: :missing_archival_token_balances_count, help: "Number of missing token balances in history"]
  @gauge [name: :unfetched_token_instances_count, help: "Number of unfetched token instances"]
  @gauge [name: :failed_token_instances_metadata_count, help: "Number of failed token instances metadata"]
  @gauge [name: :token_instances_not_uploaded_to_cdn_count, help: "Token instances not uploaded to CDN"]
  @gauge [name: :multichain_search_db_main_export_queue_count, help: "Size of the main multichain export queue"]
  @gauge [name: :multichain_search_db_export_balances_queue_count, help: "Size of the balances export queue"]
  @gauge [name: :multichain_search_db_export_counters_queue_count, help: "Size of the counters export queue"]
  @gauge [name: :multichain_search_db_export_token_info_queue_count, help: "Size of the token info export queue"]

  @spec setup() :: :ok
  def setup do
    min_blockchain_block_number =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    set_latest_block_number(min_blockchain_block_number)
    set_latest_block_timestamp(0)

    if chain_type() in @rollups do
      set_latest_batch_number(0)
      set_latest_batch_timestamp(0)
    end

    :ok
  end

  @doc """
  Defines the metric for the full processing time of a block (in microseconds).
  """
  @spec set_block_full_process(time :: integer(), fetcher :: atom()) :: :ok
  def set_block_full_process(time, fetcher) do
    Histogram.observe([name: :block_full_processing_duration_microseconds, labels: [fetcher]], time)
  end

  @doc """
  Defines the metric for the import time of a block (in microseconds).
  """
  @spec set_block_import(time :: float(), fetcher :: atom()) :: :ok
  def set_block_import(time, fetcher) do
    Histogram.observe([name: :block_import_duration_microseconds, labels: [fetcher]], time)
  end

  @doc """
  Defines the metric for the block batch fetch request time (in microseconds).
  """
  @spec set_block_batch_fetch(time :: integer(), fetcher :: atom()) :: :ok
  def set_block_batch_fetch(time, fetcher) do
    Histogram.observe([name: :block_batch_fetch_request_duration_microseconds, labels: [fetcher]], time)
  end

  @doc """
  Defines the metric for JSON-RPC node response delay (in seconds) during block import.
  """
  @spec set_json_rpc_node_delay(delay :: integer()) :: :ok
  def set_json_rpc_node_delay(delay) do
    Gauge.set([name: :delay_from_last_node_block], delay)
  end

  @doc """
  Defines the metric for the number of import errors encountered during block processing.
  """
  @spec set_import_errors_count(error_count :: integer()) :: :ok
  def set_import_errors_count(error_count \\ 1) do
    Counter.inc([name: :import_errors_count], error_count)
  end

  @doc """
  Defines the metric for memory consumed by a specific fetcher (in MB).
  """
  @spec set_memory_consumed(fetcher :: nil | atom() | String.t(), memory :: float()) :: :ok
  def set_memory_consumed(nil, _memory), do: :ok

  def set_memory_consumed(fetcher, memory) do
    Gauge.set([name: :memory_consumed, labels: [fetcher]], memory)
  end

  @spec set_latest_block_number(number :: integer()) :: :ok
  defp set_latest_block_number(number) do
    Gauge.set([name: :latest_block_number], number)
  end

  @spec set_latest_block_timestamp(timestamp :: integer()) :: :ok
  defp set_latest_block_timestamp(timestamp) do
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
    set_latest_block_number(number)
    set_latest_block_timestamp(DateTime.to_unix(timestamp))
  end

  @gauge [name: :latest_batch_number, help: "L2 latest batch number"]

  @gauge [name: :latest_batch_timestamp, help: "L2 latest batch timestamp"]

  defp set_latest_batch_number(number) do
    Gauge.set([name: :latest_batch_number], number)
  end

  defp set_latest_batch_timestamp(timestamp) do
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
    if chain_type() in @rollups do
      set_latest_batch_number(number)
      set_latest_batch_timestamp(DateTime.to_unix(timestamp))
    else
      :ok
    end
  end

  @doc """
  Defines the metric for the number of blocks missing in the chain.
  """
  @spec missing_blocks_count(integer()) :: :ok
  def missing_blocks_count(value), do: Gauge.set([name: :missing_blocks_count], value)

  @doc """
  Defines the metric for the number of blocks with not yet fetched internal transactions.
  """
  @spec missing_internal_transactions_count(integer()) :: :ok
  def missing_internal_transactions_count(value), do: Gauge.set([name: :missing_internal_transactions_count], value)

  @doc """
  Defines the metric for the number of missing current token balances.
  """
  @spec missing_current_token_balances_count(integer()) :: :ok
  def missing_current_token_balances_count(value),
    do: Gauge.set([name: :missing_current_token_balances_count], value)

  @doc """
  Defines the metric for the number of missing token balances in history.
  """
  @spec missing_archival_token_balances_count(integer()) :: :ok
  def missing_archival_token_balances_count(value), do: Gauge.set([name: :missing_archival_token_balances_count], value)

  @doc """
  Defines the metric for the number of unfetched token instances.
  """
  @spec unfetched_token_instances_count(integer()) :: :ok
  def unfetched_token_instances_count(value),
    do: Gauge.set([name: :unfetched_token_instances_count], value)

  @doc """
  Defines the metric for the number of failed token instances metadata.
  """
  @spec failed_token_instances_metadata_count(integer()) :: :ok
  def failed_token_instances_metadata_count(value),
    do: Gauge.set([name: :failed_token_instances_metadata_count], value)

  @doc """
  Defines the metric for the number of token instances not uploaded to CDN.
  """
  @spec token_instances_not_uploaded_to_cdn_count(integer()) :: :ok
  def token_instances_not_uploaded_to_cdn_count(value),
    do: Gauge.set([name: :token_instances_not_uploaded_to_cdn_count], value)

  @doc """
  Defines the metric for the size of the main multichain export queue.
  """
  @spec multichain_search_db_main_export_queue_count(integer()) :: :ok
  def multichain_search_db_main_export_queue_count(value),
    do: Gauge.set([name: :multichain_search_db_main_export_queue_count], value)

  @doc """
  Defines the metric for the size of the balances export queue.
  """
  @spec multichain_search_db_export_balances_queue_count(integer()) :: :ok
  def multichain_search_db_export_balances_queue_count(value),
    do: Gauge.set([name: :multichain_search_db_export_balances_queue_count], value)

  @doc """
  Defines the metric for the size of the counters export queue.
  """
  @spec multichain_search_db_export_counters_queue_count(integer()) :: :ok
  def multichain_search_db_export_counters_queue_count(value),
    do: Gauge.set([name: :multichain_search_db_export_counters_queue_count], value)

  @doc """
  Defines the metric for the size of the token info export queue.
  """
  @spec multichain_search_db_export_token_info_queue_count(integer()) :: :ok
  def multichain_search_db_export_token_info_queue_count(value),
    do: Gauge.set([name: :multichain_search_db_export_token_info_queue_count], value)
end
