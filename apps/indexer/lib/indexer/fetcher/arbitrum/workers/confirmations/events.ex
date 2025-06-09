defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events do
  @moduledoc """
  Provides functionality for fetching and parsing Arbitrum's SendRootUpdated events.

  This module is responsible for retrieving event logs from the Arbitrum Outbox
  contract and extracting rollup block hashes from SendRootUpdated events. It
  implements caching mechanisms to optimize RPC calls when fetching logs for the
  same block ranges.
  """

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias Indexer.Helper, as: IndexerHelper

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_debug: 1, log_warning: 1]

  require Logger

  @typedoc """
    A map containing list of transaction logs for a specific block range.
    - the key is the tuple with the start and end of the block range
    - the value is the list of transaction logs received for the block range
  """
  @type cached_logs :: %{{non_neg_integer(), non_neg_integer()} => [%{String.t() => any()}]}

  @doc """
    Retrieves `SendRootUpdated` event logs from the `Outbox` contract for a specified block range.

    Fetches logs either from the provided cache to minimize RPC calls, or directly from
    the RPC node if not cached. Updates the cache with newly fetched logs.

    ## Parameters
    - `start_block`: Starting block number for log retrieval
    - `end_block`: Ending block number for log retrieval
    - `outbox_address`: Address of the `Outbox` contract
    - `json_rpc_named_arguments`: JSON RPC connection configuration
    - `cache`: Optional map of previously fetched logs, defaults to empty map

    ## Returns
    - Tuple containing:
      * List of `SendRootUpdated` event logs
      * Updated cache including newly fetched logs
  """
  @spec get_logs_for_confirmations(
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          __MODULE__.cached_logs()
        ) :: {[%{String.t() => any()}], __MODULE__.cached_logs()}
  def get_logs_for_confirmations(start_block, end_block, outbox_address, json_rpc_named_arguments, cache \\ %{})
      when start_block <= end_block do
    # TODO: consider to have a persistent cache in DB to reduce the number of getLogs requests
    {logs, new_cache} =
      case cache[{start_block, end_block}] do
        nil ->
          {:ok, rpc_logs} =
            IndexerHelper.get_logs(
              start_block,
              end_block,
              outbox_address,
              [ArbitrumEvents.send_root_updated()],
              json_rpc_named_arguments
            )

          {rpc_logs, Map.put(cache, {start_block, end_block}, rpc_logs)}

        cached_logs ->
          {cached_logs, cache}
      end

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} SendRootUpdated logs")
    end

    {logs, new_cache}
  end

  @doc """
    Extracts the rollup block hash from a `SendRootUpdated` event log.

    ## Parameters
    - `event`: Event log map from `eth_getLogs` containing "topics" array where
      the rollup block hash is the third element

    ## Returns
    - A rollup block hash in hex format starting with "0x"
  """
  @spec send_root_updated_event_parse(%{String.t() => any()}) :: String.t()
  def send_root_updated_event_parse(event) do
    [_, _, l2_block_hash] = event["topics"]

    l2_block_hash
  end

  @doc """
    Fetches and sorts rollup block numbers from `SendRootUpdated` events in the specified L1 block range.

    Retrieves logs from the Outbox contract and extracts the top confirmed rollup block numbers.
    The block numbers are sorted in descending order to ensure proper handling of overlapping
    confirmations by finding the highest already-confirmed block below the current confirmation.
    Uses caching to minimize RPC calls.

    ## Parameters
    - `log_start`: Starting L1 block number for log retrieval
    - `log_end`: Ending L1 block number for log retrieval
    - `l1_outbox_config`: Configuration for the Arbitrum outbox contract
    - `cache`: Cache for logs to minimize RPC calls

    ## Returns
    A tuple containing:
    - `{:ok, sorted_block_numbers, new_cache, logs_length}` where:
      * `sorted_block_numbers` is a list of rollup block numbers in descending order
      * `new_cache` is the updated logs cache
      * `logs_length` is the number of logs processed
    - `{:error, nil, new_cache, logs_length}` if any block hash cannot be resolved
  """
  @spec fetch_and_sort_confirmations_logs(
          non_neg_integer(),
          non_neg_integer(),
          %{
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          cached_logs()
        ) ::
          {:ok, [non_neg_integer()], cached_logs(), non_neg_integer()} | {:error, nil, cached_logs(), non_neg_integer()}
  def fetch_and_sort_confirmations_logs(log_start, log_end, l1_outbox_config, cache) do
    {logs, new_cache} =
      get_logs_for_confirmations(
        log_start,
        log_end,
        l1_outbox_config.outbox_address,
        l1_outbox_config.json_rpc_named_arguments,
        cache
      )

    logs_length = length(logs)

    # Process each log to extract block numbers
    blocks =
      Enum.reduce_while(logs, {:ok, []}, fn log, {:ok, acc} ->
        log_debug("Examining the transaction #{log["transactionHash"]}")

        rollup_block_hash = send_root_updated_event_parse(log)
        rollup_block_num = DbSettlement.rollup_block_hash_to_num(rollup_block_hash)

        case rollup_block_num do
          nil ->
            log_warning("The rollup block ##{rollup_block_hash} not found")
            {:halt, :error}

          value ->
            log_debug("Found rollup block ##{rollup_block_num}")
            {:cont, {:ok, [value | acc]}}
        end
      end)

    case blocks do
      {:ok, list} ->
        # Sort block numbers in descending order to find highest confirmed block first
        sorted = Enum.sort(list, :desc)
        {:ok, sorted, new_cache, logs_length}

      :error ->
        {:error, nil, new_cache, logs_length}
    end
  end
end
